// lib/painters/eyebrow_painter.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// -----------------------------------------------------------------------------
// Small structs (moved to top-level)
// -----------------------------------------------------------------------------

class _Validated {
  final List<ui.Offset> points;
  final double opacityFactor;
  const _Validated({required this.points, required this.opacityFactor});
}

class _BrowAnchors {
  final ui.Offset head;
  final ui.Offset arch;
  final ui.Offset tail;
  const _BrowAnchors(this.head, this.arch, this.tail);
}

class _CorridorConstrained {
  final List<ui.Offset> center;
  final List<ui.Offset> top;
  final List<ui.Offset> bottom;
  const _CorridorConstrained({required this.center, required this.top, required this.bottom});
}

class EyebrowPainter {
  final Face face;

  /// Production brow color (used only when debugMode == false)
  final Color browColor;

  /// User intensity (0..1)
  final double intensity;

  /// Brow thickness multiplier
  final double thickness;

  /// Scene luminance (0..1) - used only in production
  final double sceneLuminance;

  /// Optional debug overlay
  final bool debugMode;

  /// If the camera preview is mirrored.
  /// If you already mirror the image before ML, set this to false.
  final bool isMirrored;

  /// ✅ FIX #1: Compatibility only (kept so older callers compile).
  /// Styling is intentionally out of scope for this task.
  final bool hairStrokes;

  /// ✅ NEW: Debug brow color (super dark brown)
  final Color debugBrowColor;

  /// ✅ NEW: Debug brow opacity
  final double debugBrowOpacity;

  /// ✅ NEW: Whether to show debug points (small circles) in debug mode
  final bool debugShowPoints;

  /// EMA stabilization strength (0..0.98)
  /// Higher = smoother (less jitter), but slightly more lag.
  final double emaAlpha;

  /// How long to keep caches
  final Duration emaTtl;

  /// When landmarks disappear, keep last good points briefly to prevent flicker
  final Duration holdLastGood;

  /// Minimum number of eyebrow points required for "good"
  final int minPoints;

  EyebrowPainter({
    required this.face,
    required this.browColor,
    required this.intensity,
    this.thickness = 1.0,
    this.sceneLuminance = 0.50,
    this.debugMode = false,
    this.isMirrored = false,
    // ✅ FIX #1: Add hairStrokes parameter for compatibility
    this.hairStrokes = false,
    // ✅ NEW: Add debug brow color and opacity
    this.debugBrowColor = const Color(0xFF1A0E0A), // super dark brown
    this.debugBrowOpacity = 0.55,
    // ✅ NEW: Whether to show debug points (small circles) in debug mode
    this.debugShowPoints = false, // ✅ Default to false for cleaner debug
    this.emaAlpha = 0.82,
    this.emaTtl = const Duration(seconds: 6),
    this.holdLastGood = const Duration(milliseconds: 250),
    this.minPoints = 4,
  });

  // ---------------------------------------------------------------------------
  // CACHES (static: shared across frames)
  // ---------------------------------------------------------------------------

  // EMA cache (same count points)
  static final Map<String, List<ui.Offset>> _emaCache = {};
  static final Map<String, DateTime> _emaTouched = {};

  // Last-good cache (survives brief landmark dropouts)
  static final Map<String, List<ui.Offset>> _lastGood = {};
  static final Map<String, DateTime> _lastGoodTouched = {};
  static final Map<String, int> _missingFrames = {};

  // ✅ FIX #2: Use braces for string interpolation
  String _key(String side) {
    final tid = face.trackingId;
    if (tid == null) return 'NO_TRACK_${side}_${identityHashCode(face)}'; // ✅ FIXED
    return 'TID_${tid}_$side';
  }

  void _pruneCaches() {
    final now = DateTime.now();
    final dead = <String>[];

    _emaTouched.forEach((k, t) {
      if (now.difference(t) > emaTtl) dead.add(k);
    });

    for (final k in dead) {
      _emaTouched.remove(k);
      _emaCache.remove(k);
    }

    final deadGood = <String>[];
    _lastGoodTouched.forEach((k, t) {
      if (now.difference(t) > emaTtl) deadGood.add(k);
    });

    for (final k in deadGood) {
      _lastGoodTouched.remove(k);
      _lastGood.remove(k);
      _missingFrames.remove(k);
    }
  }

  // ---------------------------------------------------------------------------
  // ENTRY
  // ---------------------------------------------------------------------------

  void paint(Canvas canvas, Size size) {
    final k0 = intensity.clamp(0.0, 1.0);
    if (k0 <= 0.0) return;

    _pruneCaches();

    // Fetch TOP + BOTTOM contours
    var leftTop = _contourOffsets(face.contours[FaceContourType.leftEyebrowTop]?.points);
    var leftBot = _contourOffsets(face.contours[FaceContourType.leftEyebrowBottom]?.points);

    var rightTop = _contourOffsets(face.contours[FaceContourType.rightEyebrowTop]?.points);
    var rightBot = _contourOffsets(face.contours[FaceContourType.rightEyebrowBottom]?.points);

    // Centerlines
    var leftTrace = _browCenterline(top: leftTop, bottom: leftBot, t: 0.65);
    var rightTrace = _browCenterline(top: rightTop, bottom: rightBot, t: 0.65);

    // Eye contours for constraints
    var leftEye = _contourOffsets(face.contours[FaceContourType.leftEye]?.points);
    var rightEye = _contourOffsets(face.contours[FaceContourType.rightEye]?.points);

    final hasAny = leftTrace.length >= minPoints || rightTrace.length >= minPoints;
    final hasAnyCached = _lastGood.isNotEmpty;
    if (!hasAny && !hasAnyCached) return;

    // Detect swapped left/right (MLKit can flip in some pipelines)
    if (leftTrace.length >= minPoints && rightTrace.length >= minPoints) {
      final lx = _avgX(leftTrace);
      final rx = _avgX(rightTrace);
      final looksSwapped = lx > rx;
      if (looksSwapped) {
        // swap centerline
        final tmpTrace = leftTrace;
        leftTrace = rightTrace;
        rightTrace = tmpTrace;

        // swap top/bottom too (IMPORTANT for boundary-safe hair strokes)
        final tmpTop = leftTop;
        leftTop = rightTop;
        rightTop = tmpTop;

        final tmpBot = leftBot;
        leftBot = rightBot;
        rightBot = tmpBot;

        // swap eyes too (so constraints remain correct)
        final tmpEye = leftEye;
        leftEye = rightEye;
        rightEye = tmpEye;
      }
    }

    final mirrorOrdering = isMirrored;

    _drawBrowSide(
      canvas: canvas,
      sideKey: _key('L'),
      rawCenter: leftTrace,
      rawTop: leftTop,
      rawBottom: leftBot,
      eyePts: leftEye,
      isLeft: true,
      k0: k0,
      mirrorOrdering: mirrorOrdering,
    );

    _drawBrowSide(
      canvas: canvas,
      sideKey: _key('R'),
      rawCenter: rightTrace,
      rawTop: rightTop,
      rawBottom: rightBot,
      eyePts: rightEye,
      isLeft: false,
      k0: k0,
      mirrorOrdering: mirrorOrdering,
    );
  }

  // ---------------------------------------------------------------------------
  // BROW CENTERLINE HELPER
  // ---------------------------------------------------------------------------

  List<ui.Offset> _browCenterline({
    required List<ui.Offset> top,
    required List<ui.Offset> bottom,
    double t = 0.65,
  }) {
    if (top.length < 4 || bottom.length < 4) return const [];

    // Force stable geometry count for real rendering
    const int targetN = 18;

    final topR = _resampleAny(top, targetN);
    final botR = _resampleAny(bottom, targetN);

    final tt = t.clamp(0.0, 1.0);

    return List<ui.Offset>.generate(targetN, (i) {
      final a = topR[i];
      final b = botR[i];
      return ui.Offset(
        ui.lerpDouble(a.dx, b.dx, tt)!,
        ui.lerpDouble(a.dy, b.dy, tt)!,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // SIDE PROCESSING PIPELINE
  // ---------------------------------------------------------------------------

  void _drawBrowSide({
    required Canvas canvas,
    required String sideKey,
    required List<ui.Offset> rawCenter,
    required List<ui.Offset> rawTop,
    required List<ui.Offset> rawBottom,
    required List<ui.Offset> eyePts,
    required bool isLeft,
    required double k0,
    required bool mirrorOrdering,
  }) {
    final box = face.boundingBox;
    final faceW = max(1.0, box.width);
    final faceH = max(1.0, box.height);

    // 1) Validate centerline only (prevents flicker). If centerline is bad, we fade / fallback.
    final validated = _validateOrFallback(
      key: sideKey,
      raw: rawCenter,
      minPoints: minPoints,
    );
    if (validated.points.isEmpty) return;

    // 2) Order all three sets consistently (inner -> tail)
    var centerOrdered = _orderBrowPoints(
      validated.points,
      isLeft: isLeft,
      mirrorOrdering: mirrorOrdering,
    );

    var topOrdered = _orderBrowPoints(
      rawTop,
      isLeft: isLeft,
      mirrorOrdering: mirrorOrdering,
    );

    var botOrdered = _orderBrowPoints(
      rawBottom,
      isLeft: isLeft,
      mirrorOrdering: mirrorOrdering,
    );

    // 3) Constrain above eye — apply SAME constraint to center/top/bottom
    final constrained = _constrainBrowCorridorAboveEye(
      center: centerOrdered,
      top: topOrdered,
      bottom: botOrdered,
      eye: eyePts,
      faceBox: box,
      faceH: faceH,
    );

    centerOrdered = constrained.center;
    topOrdered = constrained.top;
    botOrdered = constrained.bottom;

    // 4) EMA smooth center + corridor (stability without heavy lag)
    final centerSmoothed = _emaSmoothPoints(key: sideKey, raw: centerOrdered);

    // Use separate keys for top/bottom smoothing (same caches, cheap)
    final topSmoothed = _emaSmoothPoints(key: '${sideKey}_T', raw: topOrdered);
    final botSmoothed = _emaSmoothPoints(key: '${sideKey}_B', raw: botOrdered);

    // 5) Stroke thickness scaling
    final baseStroke = (faceW * 0.010).clamp(1.4, 4.2);
    final strokeW = baseStroke * thickness.clamp(0.75, 1.60);

    // 6) Safety opacity (fade when missing/unstable)
    final safetyOpacity = validated.opacityFactor;

    // 7) Lighting
    final l = sceneLuminance.clamp(0.0, 1.0);
    final darkT = ((0.35 - l) / 0.35).clamp(0.0, 1.0);

    // 8) Opacity math
    final eased = pow(k0, 1.6).toDouble();
    final maxBrowOpacity = 0.22; // slightly higher so it won't vanish
    final lightingFactor = ui.lerpDouble(1.0, 0.88, darkT)!;

    var opacity = (eased * maxBrowOpacity * lightingFactor * safetyOpacity).clamp(0.0, 1.0);

    // ✅ FORCE VISIBILITY when user slider is high (tuning safety)
    // This prevents the "eyebrows disappear at 100%" problem.
    if (intensity >= 0.90) {
      opacity = max(opacity, 0.10);
    }

    final color = _softenColor(browColor, darkT: darkT);

    _drawBrow(
      canvas: canvas,
      centerPts: centerSmoothed,
      topPts: topSmoothed,
      bottomPts: botSmoothed,
      box: box,
      faceW: faceW,
      faceH: faceH,
      strokeW: strokeW,
      color: color,
      opacity: opacity,
      isLeft: isLeft,
      darkT: darkT,
      safetyOpacity: safetyOpacity,
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ UPDATED _drawBrow() METHOD WITH ALL 5 FIXES + MIN SPACING PATCH
  // ---------------------------------------------------------------------------

  void _drawBrow({
    required Canvas canvas,
    required List<ui.Offset> centerPts,
    required List<ui.Offset> topPts,
    required List<ui.Offset> bottomPts,
    required Rect box,
    required double faceW,
    required double faceH,
    required double strokeW,
    required Color color,
    required double opacity,
    required bool isLeft,
    required double darkT,
    required double safetyOpacity,
  }) {
    // Need corridor data
    if (centerPts.length < 4 || topPts.length < 4 || bottomPts.length < 4) return;

    // Stable geometry counts
    const int n = 24;
    final c = _resampleAny(centerPts, n);
    final t = _resampleAny(topPts, n);
    final b = _resampleAny(bottomPts, n);

    // Bounds for layer (tight, fast)
    final bounds = _boundsOf3(c, t, b).inflate(max(14.0, strokeW * 10));

    // -------------------------
    // DEBUG MODE: show corridor + center
    // -------------------------
    if (debugMode) {
      final debugMaster =
          (pow(intensity.clamp(0.0, 1.0), 1.2).toDouble() * debugBrowOpacity).clamp(0.0, debugBrowOpacity);

      final corridorPaintTop = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = debugBrowColor.withOpacity(debugMaster * 0.85 * safetyOpacity);

      final corridorPaintBottom = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = debugBrowColor.withOpacity(debugMaster * 0.65 * safetyOpacity);

      final centerPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..color = debugBrowColor.withOpacity(debugMaster * 1.0 * safetyOpacity);

      canvas.drawPath(_buildSmoothOpenPath(t), corridorPaintTop);
      canvas.drawPath(_buildSmoothOpenPath(b), corridorPaintBottom);
      canvas.drawPath(_buildSmoothOpenPath(c), centerPaint);

      if (debugShowPoints) {
        final dot = Paint()..color = Colors.white.withOpacity(0.85 * safetyOpacity);
        for (final pt in c) {
          canvas.drawCircle(pt, 2.0, dot);
        }
      }
      return;
    }

    // -------------------------
    // PRODUCTION
    // -------------------------
    final master = opacity.clamp(0.0, 0.35);
    final visibleMaster = intensity >= 0.90 ? max(master, 0.085) : master;
    if (visibleMaster < 0.004) return;

    // Closed corridor path (top + reversed bottom)
    final corridorPath = _buildCorridorClosedPath(top: t, bottom: b);

    // ✅ FIX #5: Slight asymmetry between brows (subtle)
    // Change RNG seed with extra skew for left/right
    final seed = (face.trackingId ?? 7) * 10007 + (isLeft ? 31 : 97) + (isLeft ? 13 : 29);
    final rng = Random(seed);

    // Hair count (target 120–280 total per brow, device-safe)
    // FaceW scales it, intensity scales it a bit, but we keep clamps.
    final targetHairCount = ((150 + faceW * 1.15) * ui.lerpDouble(0.85, 1.15, intensity.clamp(0.0, 1.0))!)
        .round()
        .clamp(120, 280);

    // Corridor thickness reference (for blur + lengths)
    double avgThick = 0.0;
    for (int i = 0; i < n; i++) {
      avgThick += (t[i] - b[i]).distance;
    }
    avgThick = (avgThick / n).clamp(3.0, 26.0);

    // ✅ PATCH: prevent overlapping "one-line" stacking
    final starts = <ui.Offset>[];
    final minStartDist = (avgThick * 0.18).clamp(1.2, 3.2);

    bool tooClose(ui.Offset p) {
      for (final s in starts) {
        if ((s - p).distance < minStartDist) return true;
      }
      return false;
    }

    // Choose blend mode for base depending on exposure:
    // brighter scenes => multiply looks too harsh, softLight is safer.
    final baseBlend = (sceneLuminance >= 0.52) ? BlendMode.softLight : BlendMode.multiply;

    // ---- Layer for brow (clip everything to corridor) ----
    canvas.saveLayer(bounds, Paint());
    canvas.save();
    canvas.clipPath(corridorPath);

    // =====================================================
    // 1) POWDER MASS (blurred gradient fill) — FIX #1
    // =====================================================
    final corridorCenter = _corridorCenter(t, b);
    final head = corridorCenter.first;
    final tail = corridorCenter.last;

    final grad = ui.Gradient.linear(
      head,
      tail,
      [
        // ✅ FIX #1: Make powder base 2× stronger
        // INNER
        color.withOpacity(visibleMaster * 0.18 * safetyOpacity),
        // MID
        color.withOpacity(visibleMaster * 0.24 * safetyOpacity),
        // TAIL
        color.withOpacity(visibleMaster * 0.30 * safetyOpacity),
      ],
      [0.0, 0.55, 1.0],
    );

    final powderPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..shader = grad
      ..blendMode = baseBlend
      // ✅ FIX #1: Slightly increase blur
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        (avgThick * 0.30).clamp(0.9, 3.2), // Changed from 0.22 to 0.30
      );

    // Slightly "inflate" powder by drawing path twice with tiny offset blur feel
    canvas.drawPath(corridorPath, powderPaint);

    // Tail deepen (very subtle) — keeps cosmetic gradient logic
    final tailDeepen = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.multiply
      ..color = Colors.black.withOpacity((visibleMaster * 0.035).clamp(0.0, 0.07) * safetyOpacity)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, (avgThick * 0.18).clamp(0.7, 2.4));

    final tailZone = _tailZonePath(corridorCenter, t, b, startU: 0.68);
    canvas.drawPath(tailZone, tailDeepen);

    // ✅ FIX #4: Add micro blur pass ONLY at head (before hairs)
    if (corridorCenter.length > 5) {
      // Find the head region (u < 0.22)
      final headStartIndex = (0.22 * (corridorCenter.length - 1)).floor().clamp(0, corridorCenter.length - 1);
      
      if (headStartIndex > 0) {
        // Create a path for just the head region
        final headTop = t.sublist(0, headStartIndex + 1);
        final headBottom = b.sublist(0, headStartIndex + 1).reversed.toList();
        
        final headPath = Path();
        if (headTop.isNotEmpty && headBottom.isNotEmpty) {
          headPath.moveTo(headTop.first.dx, headTop.first.dy);
          for (int i = 1; i < headTop.length; i++) {
            headPath.lineTo(headTop[i].dx, headTop[i].dy);
          }
          for (int i = 0; i < headBottom.length; i++) {
            headPath.lineTo(headBottom[i].dx, headBottom[i].dy);
          }
          headPath.close();
          
          canvas.drawPath(
            headPath,
            Paint()
              ..blendMode = BlendMode.softLight
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, avgThick * 0.35)
              ..color = color.withOpacity(visibleMaster * 0.06 * safetyOpacity),
          );
        }
      }
    }

    // =====================================================
    // 2) HAIR STROKES (quadratic beziers, seeded, clipped)
    // =====================================================
    final hairPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.multiply;

    // Optional soft diffusion pass (keeps hairs from looking "stamped")
    final hairHaze = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.softLight
      // ✅ FIX #2: Reduce haze slightly
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, (avgThick * 0.14).clamp(0.6, 1.8));

    // Hair thickness (realistic)
    final minW = (strokeW * 0.10).clamp(0.40, 0.70);
    final maxW = (strokeW * 0.18).clamp(0.55, 1.10);

    // Density logic: head lighter, mid densest, tail darker/defined
    double densityAt(double u) {
      // head very light
      if (u < 0.18) return ui.lerpDouble(0.35, 0.75, u / 0.18)!;
      // mid/arch dense
      if (u < 0.70) return ui.lerpDouble(0.85, 1.00, (u - 0.18) / (0.70 - 0.18))!;
      // tail still dense but not "blocky"
      return ui.lerpDouble(0.95, 0.90, (u - 0.70) / (1.0 - 0.70))!;
    }

    double shadeAt(double u) {
      // cosmetic gradient: inner lighter, tail darker
      return ui.lerpDouble(0.62, 1.25, pow(u, 1.35).toDouble())!;
    }

    // Generate hairs (stable order => no sparkle)
    for (int k = 0; k < targetHairCount; k++) {
      // ✅ PATCH: stratified u (even distribution + tiny jitter)
      final baseU = (k + 0.5) / targetHairCount;
      final u = (baseU + (rng.nextDouble() - 0.5) * 0.02).clamp(0.0, 1.0);

      // ✅ FIX #3: Kill structure at brow head
      // Fade out head hairs aggressively
      final headFade = u < 0.20
        ? ui.lerpDouble(0.25, 1.0, u / 0.20)!
        : 1.0;

      // v: inside corridor (0=bottom, 1=top)
      // keep inside boundaries; also bias toward center so hairs don't leak.
      final rv = rng.nextDouble();
      final v = (0.18 + rv * 0.64); // [0.18..0.82]

      // Apply density gating (head fewer hairs)
      if (rng.nextDouble() > densityAt(u)) continue;

      // Sample corridor at u (interpolate indices)
      final p = _sampleCorridorPoint(t, b, u, v);

      // Direction logic: inner more vertical, mid angled, tail more horizontal
      final dir = _hairDirectionAtU(c, u, isLeft: isLeft);

      // Length logic: head shorter, mid medium, tail slightly longer
      final baseLen = ui.lerpDouble(1.8, 5.2, sin(pi * u))!;
      final tailBonus = ui.lerpDouble(0.0, 1.4, pow(u, 1.6).toDouble())!;
      final len = (baseLen + tailBonus + rng.nextDouble() * 1.9) * (0.85 + 0.25 * shadeAt(u));

      // Slight curve + jitter
      final jitter = (rng.nextDouble() - 0.5);
      final curveAmt = (avgThick * 0.10).clamp(0.4, 1.4);

      final start = ui.Offset(
        p.dx + jitter * curveAmt,
        p.dy + jitter * curveAmt * 0.45,
      );

      // ✅ PATCH: skip if this start would overlap a previous hair start
      if (tooClose(start)) continue;
      starts.add(start);

      // end point
      final end = ui.Offset(start.dx + dir.dx * len, start.dy + dir.dy * len);

      // control point (quadratic) => realistic arc, not a straight line
      final ctrl = ui.Offset(
        (start.dx + end.dx) * 0.5 + (-dir.dy) * (jitter * curveAmt * 0.8),
        (start.dy + end.dy) * 0.5 + (dir.dx) * (jitter * curveAmt * 0.35),
      );

      // ✅ FIX #2: Reduce hair dominance (very important)
      // Change hair alpha multiplier
      final a = (visibleMaster * 
          // ✅ OLD: ui.lerpDouble(0.12, 0.34, pow(u, 1.15).toDouble())
          // ✅ NEW: Reduce hair alpha
          ui.lerpDouble(0.08, 0.26, pow(u, 1.15).toDouble())! * 
          safetyOpacity * 
          headFade) // ✅ FIX #3: Apply head fade
          .clamp(0.03, 0.36);

      final w = ui.lerpDouble(minW, maxW, pow(u, 0.9).toDouble())!;
      hairPaint
        ..strokeWidth = w
        ..color = color.withOpacity(a);

      hairHaze
        ..strokeWidth = w * 1.35
        // ✅ FIX #2: Reduce haze opacity
        ..color = color.withOpacity(a * 0.28); // Changed from 0.40 to 0.28

      final hairPath = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);

      canvas.drawPath(hairPath, hairPaint);
      canvas.drawPath(hairPath, hairHaze);
    }

    // =====================================================
    // 3) MICRO-GRAIN (optional, ultra subtle)
    // =====================================================
    // Use only when you want "powder grain", not visible dots.
    // Keep it extremely subtle.
    final enableGrain = true;
    if (enableGrain && visibleMaster > 0.02) {
      final grainSeed = seed * 31 + 11;
      final grng = Random(grainSeed);

      // A small number is enough; too many becomes visible "dots".
      final grainCount = (80 + avgThick * 10).round().clamp(90, 180);

      final grainPaint = Paint()
        ..isAntiAlias = true
        ..blendMode = BlendMode.softLight
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.0
        ..color = Colors.white.withOpacity((visibleMaster * 0.018).clamp(0.0, 0.03) * safetyOpacity);

      // Scatter within corridor using u,v sampling (stable)
      for (int i = 0; i < grainCount; i++) {
        final u = grng.nextDouble();
        final v = 0.22 + grng.nextDouble() * 0.56;
        final p = _sampleCorridorPoint(t, b, u, v);

        // Tiny jitter
        final jx = (grng.nextDouble() - 0.5) * 1.2;
        final jy = (grng.nextDouble() - 0.5) * 1.0;

        canvas.drawPoints(
          ui.PointMode.points,
          [ui.Offset(p.dx + jx, p.dy + jy)],
          grainPaint,
        );
      }
    }

    // ---- restore clip + layer ----
    canvas.restore();
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // ✅ HELPER FUNCTIONS (NEW - ADDED BELOW)
  // ---------------------------------------------------------------------------

  Path _buildCorridorClosedPath({
    required List<ui.Offset> top,
    required List<ui.Offset> bottom,
  }) {
    // Smooth both edges then close
    final tPath = _buildSmoothOpenPath(top);
    final bRev = bottom.reversed.toList();
    final bPath = _buildSmoothOpenPath(bRev);

    final m = Path()..addPath(tPath, ui.Offset.zero);
    // Connect end of top to start of reversed bottom
    if (bRev.isNotEmpty) {
      m.lineTo(bRev.first.dx, bRev.first.dy);
    }
    m.addPath(bPath, ui.Offset.zero);
    m.close();
    return m;
  }

  List<ui.Offset> _corridorCenter(List<ui.Offset> top, List<ui.Offset> bottom) {
    final n = min(top.length, bottom.length);
    return List<ui.Offset>.generate(n, (i) {
      return ui.Offset(
        ui.lerpDouble(bottom[i].dx, top[i].dx, 0.5)!,
        ui.lerpDouble(bottom[i].dy, top[i].dy, 0.5)!,
      );
    });
  }

  /// Small zone path near tail for subtle deepening.
  Path _tailZonePath(List<ui.Offset> center, List<ui.Offset> top, List<ui.Offset> bottom, {required double startU}) {
    final n = min(min(center.length, top.length), bottom.length);
    final startI = (startU.clamp(0.0, 1.0) * (n - 1)).floor().clamp(0, n - 2);

    final topSeg = top.sublist(startI);
    final botSeg = bottom.sublist(startI).reversed.toList();

    final p = Path();
    if (topSeg.isEmpty || botSeg.isEmpty) return p;

    p.moveTo(topSeg.first.dx, topSeg.first.dy);
    for (int i = 1; i < topSeg.length; i++) {
      p.lineTo(topSeg[i].dx, topSeg[i].dy);
    }
    for (int i = 0; i < botSeg.length; i++) {
      p.lineTo(botSeg[i].dx, botSeg[i].dy);
    }
    p.close();
    return p;
  }

  /// Sample inside corridor at normalized u (0..1 along length) and v (0..1 bottom->top).
  ui.Offset _sampleCorridorPoint(List<ui.Offset> top, List<ui.Offset> bottom, double u, double v) {
    final n = min(top.length, bottom.length);
    if (n <= 1) return top.isNotEmpty ? top.first : const ui.Offset(0, 0);

    final fu = (u.clamp(0.0, 1.0)) * (n - 1);
    final i0 = fu.floor().clamp(0, n - 1);
    final i1 = min(n - 1, i0 + 1);
    final tt = fu - i0;

    final topP = ui.Offset(
      ui.lerpDouble(top[i0].dx, top[i1].dx, tt)!,
      ui.lerpDouble(top[i0].dy, top[i1].dy, tt)!,
    );
    final botP = ui.Offset(
      ui.lerpDouble(bottom[i0].dx, bottom[i1].dx, tt)!,
      ui.lerpDouble(bottom[i0].dy, bottom[i1].dy, tt)!,
    );

    final vv = v.clamp(0.0, 1.0);
    return ui.Offset(
      ui.lerpDouble(botP.dx, topP.dx, vv)!,
      ui.lerpDouble(botP.dy, topP.dy, vv)!,
    );
  }

  /// Hair direction changes across the brow:
  /// - head: more vertical-ish
  /// - mid: angled
  /// - tail: more horizontal-ish
  ui.Offset _hairDirectionAtU(List<ui.Offset> center, double u, {required bool isLeft}) {
    final n = center.length;
    if (n < 3) return ui.Offset(isLeft ? -0.6 : 0.6, -0.8);

    final fu = u.clamp(0.0, 1.0) * (n - 1);
    final i = fu.floor().clamp(1, n - 2);

    // Local tangent (along brow)
    final prev = center[i - 1];
    final next = center[i + 1];
    final tan = next - prev;
    final tanLen = tan.distance + 1e-6;
    final tx = tan.dx / tanLen;
    final ty = tan.dy / tanLen;

    // Normal (perpendicular)
    final nx = -ty;
    final ny = tx;

    // Outward depends on side
    final outward = isLeft ? -1.0 : 1.0;

    // Blend weights:
    // head: more vertical/up
    // mid: mix normal + slight tangent
    // tail: more tangent-ish, less vertical
    final headT = (1.0 - (u / 0.25).clamp(0.0, 1.0)); // 1 at u=0, 0 by u=0.25
    final tailT = ((u - 0.65) / 0.35).clamp(0.0, 1.0); // 0 until 0.65, 1 at 1.0

    // Base direction: outward-normal + upward bias
    double dx = nx * (0.85 * outward) + tx * 0.18;
    double dy = ny * 0.55 + ty * 0.10 - 0.40;

    // Head: more vertical (reduce horizontal drift)
    dx = ui.lerpDouble(dx, 0.10 * outward, headT)!;
    dy = ui.lerpDouble(dy, -0.95, headT)!;

    // Tail: more horizontal (align to brow length)
    dx = ui.lerpDouble(dx, tx, tailT)!;
    dy = ui.lerpDouble(dy, ty * 0.15 - 0.20, tailT)!;

    final len = sqrt(dx * dx + dy * dy) + 1e-6;
    return ui.Offset(dx / len, dy / len);
  }

  // ---------------------------------------------------------------------------
  // SMOOTH PATH BUILDER
  // ---------------------------------------------------------------------------

  Path _buildSmoothOpenPath(List<ui.Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    if (pts.length < 3) {
      path.moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      return path;
    }

    path.moveTo(pts[0].dx, pts[0].dy);

    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = (i == 0) ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = (i + 2 < pts.length) ? pts[i + 2] : pts[i + 1];

      // Catmull-Rom to Bezier
      final c1 = ui.Offset(
        p1.dx + (p2.dx - p0.dx) / 6.0,
        p1.dy + (p2.dy - p0.dy) / 6.0,
      );
      final c2 = ui.Offset(
        p2.dx - (p3.dx - p1.dx) / 6.0,
        p2.dy - (p3.dy - p1.dy) / 6.0,
      );

      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    return path;
  }

  // ---------------------------------------------------------------------------
  // VALIDATION + FLICKER SAFETY
  // ---------------------------------------------------------------------------

  _Validated _validateOrFallback({
    required String key,
    required List<ui.Offset> raw,
    required int minPoints,
  }) {
    final now = DateTime.now();

    bool good = raw.length >= minPoints;

    // Also reject if points collapse to a tiny span (often garbage)
    if (good) {
      final spanX = _spanX(raw);
      final spanY = _spanY(raw);
      if (spanX < 6.0 || spanY < 2.0) good = false;
    }

    if (good) {
      _lastGood[key] = raw;
      _lastGoodTouched[key] = now;
      _missingFrames[key] = 0;
      return _Validated(points: raw, opacityFactor: 1.0);
    }

    // Missing / unstable: use last-good briefly, fade out smoothly
    final last = _lastGood[key];
    final lastT = _lastGoodTouched[key];

    if (last == null || lastT == null) {
      return const _Validated(points: <ui.Offset>[], opacityFactor: 0.0);
    }

    final age = now.difference(lastT);
    if (age > holdLastGood) {
      return const _Validated(points: <ui.Offset>[], opacityFactor: 0.0);
    }

    final miss = (_missingFrames[key] ?? 0) + 1;
    _missingFrames[key] = miss;

    // Fade down as it keeps missing within hold window
    final fade = (1.0 - (miss / 6.0)).clamp(0.15, 0.85);

    return _Validated(points: last, opacityFactor: fade);
  }

  // ---------------------------------------------------------------------------
  // ORDERING: inner -> arch -> tail
  // ---------------------------------------------------------------------------

  List<ui.Offset> _orderBrowPoints(
  List<ui.Offset> pts, {
  required bool isLeft,
  required bool mirrorOrdering,
}) {
  if (pts.length <= 2) return pts;

  final p = List<ui.Offset>.from(pts);

  // 1) Estimate brow axis from extremes (more robust than X-only)
  // Use the two farthest points as endpoints.
  int aIdx = 0;
  int bIdx = 0;
  double bestD = -1;

  for (int i = 0; i < p.length; i++) {
    for (int j = i + 1; j < p.length; j++) {
      final d = (p[i] - p[j]).distanceSquared;
      if (d > bestD) {
        bestD = d;
        aIdx = i;
        bIdx = j;
      }
    }
  }

  final A = p[aIdx];
  final B = p[bIdx];
  final axis = B - A;
  final axisLen = axis.distance + 1e-6;
  final ux = axis.dx / axisLen;
  final uy = axis.dy / axisLen;

  // 2) Project each point onto the axis and sort by that projection
  // This preserves curve progression even if X is not monotonic.
  final scored = p.map((pt) {
    final vx = pt.dx - A.dx;
    final vy = pt.dy - A.dy;
    final s = vx * ux + vy * uy; // scalar projection along axis
    return (pt: pt, s: s);
  }).toList()
    ..sort((m, n) => m.s.compareTo(n.s));

  var ordered = scored.map((e) => e.pt).toList();

  // 3) Enforce inner -> tail direction based on side + mirroring
  // Decide if inner should be near face center:
  // Non-mirrored: left inner generally has higher X than tail; right inner lower X than tail.
  // Mirrored flips this logic.
  final start = ordered.first;
  final end = ordered.last;

  bool startLooksInner;
  if (!mirrorOrdering) {
    startLooksInner = isLeft ? (start.dx > end.dx) : (start.dx < end.dx);
  } else {
    startLooksInner = isLeft ? (start.dx < end.dx) : (start.dx > end.dx);
  }

  if (!startLooksInner) {
    ordered = ordered.reversed.toList();
  }

  // 4) Smooth to remove zig-zag noise
  return _spatialSmooth(ordered, passes: 1);
}
  // ---------------------------------------------------------------------------
  // CONSTRAINT: keep brow above eye, avoid forehead drift
  // ---------------------------------------------------------------------------

  List<ui.Offset> _constrainAboveEye({
    required List<ui.Offset> brow,
    required List<ui.Offset> eye,
    required Rect faceBox,
    required double faceH,
  }) {
    if (brow.isEmpty) return brow;

    // If eye is missing, fallback to "reasonable" zone in face box
    final fallbackEyeTop = faceBox.top + faceH * 0.35;

    final eyeTopY = eye.isEmpty ? fallbackEyeTop : eye.map((p) => p.dy).reduce(min);
    final browMinY = brow.map((p) => p.dy).reduce(min);

    // Margin above eye (prevents drifting into eyelids)
    final margin = (faceH * 0.035).clamp(6.0, 16.0);

    // Desired max brow y (must be ABOVE eyeTopY - margin)
    final maxAllowedY = eyeTopY - margin;

    // Also prevent going too high into forehead:
    final minAllowedY = faceBox.top + faceH * 0.06;

    // If brow is too low, shift up
    double shiftY = 0.0;
    if (browMinY > maxAllowedY) {
      shiftY = maxAllowedY - browMinY; // negative => move up
    }

    final shifted = brow.map((p) => ui.Offset(p.dx, p.dy + shiftY)).toList();

    // Clamp each point into [minAllowedY, maxAllowedY + small slack]
    final slack = (faceH * 0.015).clamp(2.0, 6.0);
    final topClamp = minAllowedY;
    final bottomClamp = maxAllowedY + slack;

    return shifted
        .map((p) => ui.Offset(p.dx, p.dy.clamp(topClamp, bottomClamp)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // EMA SMOOTHING (temporal)
  // ---------------------------------------------------------------------------

  List<ui.Offset> _emaSmoothPoints({
    required String key,
    required List<ui.Offset> raw,
  }) {
    if (raw.isEmpty) return raw;

    final a = emaAlpha.clamp(0.0, 0.98);

    if (a <= 0.0) {
      _emaCache[key] = List<ui.Offset>.from(raw);
      _emaTouched[key] = DateTime.now();
      return raw;
    }

    final prev = _emaCache[key];
    if (prev == null || prev.isEmpty || prev.length != raw.length) {
      _emaCache[key] = List<ui.Offset>.from(raw);
      _emaTouched[key] = DateTime.now();
      return raw;
    }

    // EMA: out = a*prev + (1-a)*raw
    final out = <ui.Offset>[];
    for (int i = 0; i < raw.length; i++) {
      final p = raw[i];
      final q = prev[i];
      out.add(ui.Offset(
        q.dx * a + p.dx * (1.0 - a),
        q.dy * a + p.dy * (1.0 - a),
      ));
    }

    _emaCache[key] = out;
    _emaTouched[key] = DateTime.now();
    return out;
  }

  // ---------------------------------------------------------------------------
  // ✅ NEW HELPER FUNCTIONS (Corridor management)
  // ---------------------------------------------------------------------------

  /// Applies the SAME eye constraint shift + clamp to center/top/bottom so the corridor stays aligned.
  _CorridorConstrained _constrainBrowCorridorAboveEye({
    required List<ui.Offset> center,
    required List<ui.Offset> top,
    required List<ui.Offset> bottom,
    required List<ui.Offset> eye,
    required Rect faceBox,
    required double faceH,
  }) {
    if (center.isEmpty) {
      return _CorridorConstrained(center: center, top: top, bottom: bottom);
    }

    final fallbackEyeTop = faceBox.top + faceH * 0.35;
    final eyeTopY = eye.isEmpty ? fallbackEyeTop : eye.map((p) => p.dy).reduce(min);

    final browMinY = center.map((p) => p.dy).reduce(min);

    final margin = (faceH * 0.035).clamp(6.0, 16.0);
    final maxAllowedY = eyeTopY - margin;

    final minAllowedY = faceBox.top + faceH * 0.06;

    double shiftY = 0.0;
    if (browMinY > maxAllowedY) {
      shiftY = maxAllowedY - browMinY;
    }

    final slack = (faceH * 0.015).clamp(2.0, 6.0);
    final topClamp = minAllowedY;
    final bottomClamp = maxAllowedY + slack;

    List<ui.Offset> apply(List<ui.Offset> pts) {
      return pts
          .map((p) => ui.Offset(p.dx, (p.dy + shiftY).clamp(topClamp, bottomClamp)))
          .toList();
    }

    return _CorridorConstrained(
      center: apply(center),
      top: apply(top),
      bottom: apply(bottom),
    );
  }

  /// Resample that works for BOTH downsample and upsample.
  List<ui.Offset> _resampleAny(List<ui.Offset> pts, int n) {
    if (pts.isEmpty) return pts;
    if (n <= 2) return [pts.first, pts.last];

    final out = <ui.Offset>[];
    final step = (pts.length - 1) / (n - 1);

    for (int i = 0; i < n; i++) {
      final idx = i * step;
      final a = idx.floor();
      final b = min(pts.length - 1, a + 1);
      final t = idx - a;

      final pa = pts[a];
      final pb = pts[b];

      out.add(ui.Offset(
        ui.lerpDouble(pa.dx, pb.dx, t)!,
        ui.lerpDouble(pa.dy, pb.dy, t)!,
      ));
    }
    return out;
  }

  Rect _boundsOf3(List<ui.Offset> a, List<ui.Offset> b, List<ui.Offset> c) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;

    void eat(ui.Offset p) {
      minX = min(minX, p.dx);
      minY = min(minY, p.dy);
      maxX = max(maxX, p.dx);
      maxY = max(maxY, p.dy);
    }

    for (final p in a) eat(p);
    for (final p in b) eat(p);
    for (final p in c) eat(p);

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  ui.Offset _clampEndToCorridor(ui.Offset end, ui.Offset top, ui.Offset bottom, {required double maxOvershoot}) {
    final cx = ui.lerpDouble(bottom.dx, top.dx, 0.5)!;
    final cy = ui.lerpDouble(bottom.dy, top.dy, 0.5)!;
    final center = ui.Offset(cx, cy);

    final v = end - center;
    final dist = v.distance;

    if (dist <= maxOvershoot) return end;

    final scale = maxOvershoot / max(1e-6, dist);
    return center + ui.Offset(v.dx * scale, v.dy * scale);
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  List<ui.Offset> _contourOffsets(List<Point<int>>? pts) {
    if (pts == null || pts.isEmpty) return const [];
    return pts.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
  }

  double _avgX(List<ui.Offset> pts) {
    if (pts.isEmpty) return 0;
    double s = 0;
    for (final p in pts) s += p.dx;
    return s / pts.length;
  }

  double _spanX(List<ui.Offset> pts) {
    double mn = double.infinity, mx = -double.infinity;
    for (final p in pts) {
      mn = min(mn, p.dx);
      mx = max(mx, p.dx);
    }
    return mx - mn;
  }

  double _spanY(List<ui.Offset> pts) {
    double mn = double.infinity, mx = -double.infinity;
    for (final p in pts) {
      mn = min(mn, p.dy);
      mx = max(mx, p.dy);
    }
    return mx - mn;
  }

  List<ui.Offset> _spatialSmooth(List<ui.Offset> pts, {int passes = 1}) {
    if (pts.length < 3) return pts;

    var cur = List<ui.Offset>.from(pts);

    for (int p = 0; p < passes; p++) {
      final out = <ui.Offset>[];
      out.add(cur.first);
      for (int i = 1; i < cur.length - 1; i++) {
        final a = cur[i - 1];
        final b = cur[i];
        final c = cur[i + 1];
        out.add(ui.Offset(
          (a.dx + 2 * b.dx + c.dx) / 4.0,
          (a.dy + 2 * b.dy + c.dy) / 4.0,
        ));
      }
      out.add(cur.last);
      cur = out;
    }

    return cur;
  }

  // ✅ Keep both resample methods for compatibility
  List<ui.Offset> _resample(List<ui.Offset> pts, int n) {
    return _resampleAny(pts, n);
  }

  Color _softenColor(Color c, {required double darkT}) {
    final hsl = HSLColor.fromColor(c);
    final s = (hsl.saturation * ui.lerpDouble(0.95, 0.85, darkT)!).clamp(0.0, 1.0);
    final l = (hsl.lightness * ui.lerpDouble(1.00, 0.92, darkT)!).clamp(0.0, 1.0);
    return hsl.withSaturation(s).withLightness(l).toColor();
  }
}

// -----------------------------------------------------------------------------
// CORRIDOR HELPER (Added at bottom of file)
// -----------------------------------------------------------------------------

bool _insideCorridor(
  ui.Offset p,
  ui.Offset top,
  ui.Offset bottom,
) {
  final minY = min(top.dy, bottom.dy);
  final maxY = max(top.dy, bottom.dy);
  return p.dy >= minY && p.dy <= maxY;
}
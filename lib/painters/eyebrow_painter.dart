// lib/painters/eyebrow_painter.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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

    // ✅ PATCH: Fetch both TOP + BOTTOM contours
    final leftTop = _contourOffsets(face.contours[FaceContourType.leftEyebrowTop]?.points);
    final leftBot = _contourOffsets(face.contours[FaceContourType.leftEyebrowBottom]?.points);

    final rightTop = _contourOffsets(face.contours[FaceContourType.rightEyebrowTop]?.points);
    final rightBot = _contourOffsets(face.contours[FaceContourType.rightEyebrowBottom]?.points);

    // Build real brow traces using centerline between top and bottom
    final leftTrace = _browCenterline(top: leftTop, bottom: leftBot, t: 0.65);
    final rightTrace = _browCenterline(top: rightTop, bottom: rightBot, t: 0.65);

    // Eye contours (used to enforce "brow must be above eye")
    final leftEye = _contourOffsets(face.contours[FaceContourType.leftEye]?.points);
    final rightEye = _contourOffsets(face.contours[FaceContourType.rightEye]?.points);

    // If both traces are missing AND no last-good, skip
    final hasAny = leftTrace.length >= minPoints || rightTrace.length >= minPoints;
    final hasAnyCached = _lastGood.isNotEmpty;
    if (!hasAny && !hasAnyCached) return;

    // Auto mirror-safe swap (ONLY if we have both)
    // If mirrored input is wrong, MLKit sometimes flips L/R.
    // We detect by average X position.
    var leftRaw = leftTrace;
    var rightRaw = rightTrace;
    if (leftRaw.length >= minPoints && rightRaw.length >= minPoints) {
      final lx = _avgX(leftRaw);
      final rx = _avgX(rightRaw);
      // Normally: left is more left on screen => lx < rx
      // If swapped: lx > rx
      final looksSwapped = lx > rx;
      if (looksSwapped) {
        final tmp = leftRaw;
        leftRaw = rightRaw;
        rightRaw = tmp;
      }
    }

    // If your preview is mirrored but ML coordinates are not, handle ordering safely.
    // This flag only affects ordering direction, not swapping (swap uses geometry).
    final mirrorOrdering = isMirrored;

    // Prepare each side using: validate -> order -> constrain -> smooth -> build curve
    _drawBrowSide(
      canvas: canvas,
      sideKey: _key('L'),
      rawPts: leftRaw,
      eyePts: leftEye,
      isLeft: true,
      k0: k0,
      mirrorOrdering: mirrorOrdering,
    );

    _drawBrowSide(
      canvas: canvas,
      sideKey: _key('R'),
      rawPts: rightRaw,
      eyePts: rightEye,
      isLeft: false,
      k0: k0,
      mirrorOrdering: mirrorOrdering,
    );
  }

  // ---------------------------------------------------------------------------
  // BROW CENTERLINE HELPER
  // ---------------------------------------------------------------------------

  /// ✅ PATCH: Build a "real brow" trace (centerline between top and bottom)
  List<ui.Offset> _browCenterline({
    required List<ui.Offset> top,
    required List<ui.Offset> bottom,
    double t = 0.65, // closer to bottom = closer to real hair line
  }) {
    if (top.length < 4 || bottom.length < 4) return const [];

    // Resample both to same count so we can pair points
    final n = min(top.length, bottom.length);
    final topR = _resample(top, n);
    final botR = _resample(bottom, n);

    final tt = t.clamp(0.0, 1.0);

    // Centerline biased toward bottom (hair sits closer to bottom contour)
    return List<ui.Offset>.generate(n, (i) {
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
    required List<ui.Offset> rawPts,
    required List<ui.Offset> eyePts,
    required bool isLeft,
    required double k0,
    required bool mirrorOrdering,
  }) {
    final box = face.boundingBox;
    final faceW = max(1.0, box.width);
    final faceH = max(1.0, box.height);

    // 1) Validate / fallback to last-good to prevent flicker
    final validated = _validateOrFallback(
      key: sideKey,
      raw: rawPts,
      minPoints: minPoints,
    );

    if (validated.points.isEmpty) return;

    // 2) Enforce consistent ordering: inner -> arch -> tail
    var ordered = _orderBrowPoints(
      validated.points,
      isLeft: isLeft,
      mirrorOrdering: mirrorOrdering,
    );

    // 3) Clamp placement relative to eye (must be above upper eyelid)
    ordered = _constrainAboveEye(
      brow: ordered,
      eye: eyePts,
      faceBox: box,
      faceH: faceH,
    );

    // 4) EMA smooth (temporal stability)
    final smoothed = _emaSmoothPoints(key: sideKey, raw: ordered);

    // 5) Stroke width baseline (placement correctness first)
    final baseStroke = (faceW * 0.010).clamp(1.4, 4.2);
    final strokeW = baseStroke * thickness.clamp(0.75, 1.60);

    // 6) Opacity safety: fade if currently "fallback/unstable"
    final safetyOpacity = validated.opacityFactor;

    // 7) Scene lighting adjustments
    final l = sceneLuminance.clamp(0.0, 1.0);
    final darkT = ((0.35 - l) / 0.35).clamp(0.0, 1.0);
    final blur = (faceW * 0.007).clamp(0.9, 3.0) * ui.lerpDouble(1.15, 0.95, l)!;

    // ✅ PATCH A: NEW opacity math - brows fade in smoothly like blush/lipstick
    // Use an easing curve so low slider values are subtle and natural.
    final eased = pow(k0, 1.6).toDouble(); // 1.4–2.0 is a good range

    // Brows should never reach lipstick-level opacity.
    // Tune these caps to taste (start conservative).
    final maxBrowOpacity = 0.20; // try 0.16–0.24 depending on your desired strength
    final lightingFactor = ui.lerpDouble(1.0, 0.88, darkT)!;

    // Final brow opacity driven by global slider
    final opacity = (eased * maxBrowOpacity * lightingFactor * safetyOpacity)
        .clamp(0.0, 1.0);

    // 8) Color with lighting adjustments
    final color = _softenColor(browColor, darkT: darkT);

    // ✅ MAIN DRAWING (updated with feathered gradient + softer blending)
    _drawBrow(
      canvas: canvas,
      pts: smoothed,
      box: box,
      faceW: faceW,
      faceH: faceH,
      strokeW: strokeW,
      blur: blur,
      color: color,
      opacity: opacity,
      isLeft: isLeft,
      darkT: darkT,
      safetyOpacity: safetyOpacity,
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ REALISTIC BROW RENDERING WITH FEATHERED GRADIENT
  // ---------------------------------------------------------------------------

  void _drawBrow({
    required Canvas canvas,
    required List<ui.Offset> pts,
    required Rect box,
    required double faceW,
    required double faceH,
    required double strokeW,
    required double blur,
    required Color color,
    required double opacity,
    required bool isLeft,
    required double darkT,
    required double safetyOpacity,
  }) {
    // Smooth/resample for stable curve
    final smooth = _resample(pts, 20);
    final curvePath = _buildSmoothOpenPath(smooth);

    // Brow body band (this is what blends like blush/lipstick)
    final band = _buildEnvelopeOutline(smooth, strokeW * 1.30);
    final bounds = band.getBounds().inflate(max(12.0, strokeW * 7));

    // -------------------------
    // DEBUG: show geometry only
    // -------------------------
    if (debugMode) {
      // ✅ PATCH C: Debug brow opacity follows global slider
      final debugMaster = (pow(intensity.clamp(0.0, 1.0), 1.2).toDouble() * debugBrowOpacity)
          .clamp(0.0, debugBrowOpacity);

      // Natural-looking debug (dark brown)
      canvas.drawPath(
        band,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.fill
          ..color = debugBrowColor.withOpacity(debugMaster * safetyOpacity),
      );

      canvas.drawPath(
        curvePath,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = debugBrowColor.withOpacity((debugMaster * 1.1).clamp(0.0, 0.85) * safetyOpacity),
      );

      // ✅ ONLY show raw points if debugShowPoints is true
      if (debugShowPoints) {
        for (final pt in pts) {
          canvas.drawCircle(
            pt,
            2.0,
            Paint()..color = Colors.white.withOpacity(0.7 * safetyOpacity),
          );
        }
      }

      return; // ✅ IMPORTANT: stop here in debug
    }

    // -------------------------
    // PRODUCTION: realistic blend (soft edges, brow hair preserved)
    // -------------------------
    canvas.saveLayer(bounds, Paint());

    // ✅ PATCH B: Do NOT clamp to a minimum. The slider must be able to make brows extremely subtle.
    final master = (opacity).clamp(0.0, 0.30);

    // If master opacity is too low, skip rendering entirely
    if (master < 0.005) {
      canvas.restore();
      return;
    }

    // Build a vertical feather gradient so edges fade naturally
    final b = band.getBounds();
    final featherShader = ui.Gradient.linear(
      ui.Offset(b.left, b.top),
      ui.Offset(b.left, b.bottom),
      [
        color.withOpacity(0.00),              // top edge fade
        color.withOpacity(master * 0.55),     // upper-middle
        color.withOpacity(master * 0.85),     // center (strongest)
        color.withOpacity(master * 0.55),     // lower-middle
        color.withOpacity(0.00),              // bottom edge fade
      ],
      [0.00, 0.22, 0.50, 0.78, 1.00],
    );

    // PASS 1) SoftLight tint (preserves eyebrow hair underneath)
    canvas.drawPath(
      band,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..shader = featherShader
        ..blendMode = BlendMode.softLight
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur * 1.30),
    );

    // PASS 2) Very subtle multiply center (adds depth but avoids "marker")
    canvas.drawPath(
      band,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..shader = featherShader
        ..blendMode = BlendMode.multiply
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur * 0.95)
        ..colorFilter = const ui.ColorFilter.mode(Colors.black, BlendMode.srcATop)
        ..color = Colors.black.withOpacity(master * 0.10), // ✅ tiny
    );

    // PASS 3) Remove harsh outline: NO strong curve line
    // (If you keep this, keep it extremely subtle)
    canvas.drawPath(
      curvePath,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW * 0.30
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withOpacity(master * 0.10)
        ..blendMode = BlendMode.softLight
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur * 0.90),
    );

    // ✅ PATCH D: Only add hair texture when intensity is medium/high
    if (intensity >= 0.35 && master > 0.02) {
      _drawBrowHairSoft(
        canvas: canvas,
        curve: smooth,
        isLeft: isLeft,
        color: color,
        masterOpacity: master,
        strokeW: strokeW,
        blur: blur,
        darkT: darkT,
      );
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // ✅ SOFTER HAIR STROKES (ultra subtle)
  // ---------------------------------------------------------------------------

  void _drawBrowHairSoft({
    required Canvas canvas,
    required List<ui.Offset> curve,
    required bool isLeft,
    required Color color,
    required double masterOpacity,
    required double strokeW,
    required double blur,
    required double darkT,
  }) {
    if (curve.length < 10) return;

    final seed = (face.trackingId ?? 7) * 1000 + (isLeft ? 23 : 41);
    final rng = Random(seed);

    // ✅ PATCH E: Softer hair: should feel like texture, not drawn lines
    final hairOpacity = (masterOpacity * 0.12).clamp(0.008, 0.03);

    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(hairOpacity)
      ..strokeWidth = max(0.45, strokeW * 0.14)
      ..blendMode = BlendMode.softLight
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur * 0.55);

    for (int i = 2; i < curve.length - 2; i++) {
      final t = i / (curve.length - 1);
      final density = (sin(pi * t)).clamp(0.15, 1.0);

      // fewer strokes = more realistic blend
      if (rng.nextDouble() > 0.35 * density) continue;

      final p0 = curve[i - 1];
      final p1 = curve[i];
      final p2 = curve[i + 1];

      final tx = p2.dx - p0.dx;
      final ty = p2.dy - p0.dy;
      final len = max(1e-6, sqrt(tx * tx + ty * ty));

      final nx = -ty / len;
      final ny = tx / len;

      final outward = isLeft ? -1.0 : 1.0;

      // shorter hairs = less "fake"
      final hairLen = (2.5 + rng.nextDouble() * 4.0) * (0.75 + 0.35 * density);

      final jx = (rng.nextDouble() - 0.5) * 0.9;
      final jy = (rng.nextDouble() - 0.5) * 0.6;

      final start = ui.Offset(p1.dx + jx, p1.dy + jy);
      final end = ui.Offset(
        start.dx + nx * hairLen + outward * 0.20,
        start.dy + ny * hairLen - 0.25,
      );

      canvas.drawLine(start, end, paint);
    }
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

    // Most ML contours already come ordered, but we force consistency:
    // Order primarily by X, direction depends on side and mirroring.
    final sorted = List<ui.Offset>.from(pts)..sort((a, b) => a.dx.compareTo(b.dx));

    // For a NON-mirrored view:
    // - Left brow: inner is more toward center (higher X than tail),
    //   so inner->tail is roughly descending X.
    // - Right brow: inner->tail is roughly ascending X.
    //
    // For mirrored view, swap ordering directions.
    final wantAscendingForLeftInnerToTail = mirrorOrdering ? true : false;
    final wantAscendingForRightInnerToTail = mirrorOrdering ? false : true;

    final ascending = isLeft ? wantAscendingForLeftInnerToTail : wantAscendingForRightInnerToTail;

    final ordered = ascending ? sorted : sorted.reversed.toList();

    // Light spatial smoothing to remove zig-zag ordering noise
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
  // ENVELOPE OUTLINE (thin boundary) from sampled normals
  // ---------------------------------------------------------------------------

  Path _buildEnvelopeOutline(List<ui.Offset> curve, double halfThickness) {
    if (curve.length < 3) return Path();

    final upper = <ui.Offset>[];
    final lower = <ui.Offset>[];

    for (int i = 0; i < curve.length; i++) {
      final p = curve[i];
      final pPrev = curve[max(0, i - 1)];
      final pNext = curve[min(curve.length - 1, i + 1)];

      final tx = pNext.dx - pPrev.dx;
      final ty = pNext.dy - pPrev.dy;
      final len = max(1e-6, sqrt(tx * tx + ty * ty));

      // Normal
      final nx = -ty / len;
      final ny = tx / len;

      upper.add(ui.Offset(p.dx + nx * halfThickness, p.dy + ny * halfThickness));
      lower.add(ui.Offset(p.dx - nx * halfThickness, p.dy - ny * halfThickness));
    }

    final path = Path()
      ..moveTo(upper.first.dx, upper.first.dy);

    for (int i = 1; i < upper.length; i++) {
      path.lineTo(upper[i].dx, upper[i].dy);
    }

    for (int i = lower.length - 1; i >= 0; i--) {
      path.lineTo(lower[i].dx, lower[i].dy);
    }

    path.close();
    return path;
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

  List<ui.Offset> _resample(List<ui.Offset> pts, int n) {
    if (pts.isEmpty) return pts;
    if (pts.length <= n) return pts;

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

  Color _softenColor(Color c, {required double darkT}) {
    final hsl = HSLColor.fromColor(c);
    final s = (hsl.saturation * ui.lerpDouble(0.95, 0.85, darkT)!).clamp(0.0, 1.0);
    final l = (hsl.lightness * ui.lerpDouble(1.00, 0.92, darkT)!).clamp(0.0, 1.0);
    return hsl.withSaturation(s).withLightness(l).toColor();
  }
}

// -----------------------------------------------------------------------------
// Small structs
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
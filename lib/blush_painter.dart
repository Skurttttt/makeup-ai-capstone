import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'look_engine.dart';

class BlushPainter {
  final Face face;
  final Color blushColor;
  final double intensity;
  final FaceShape faceShape;

  /// Optional sampled skin color (FaceProfile avgR/G/B)
  final Color? skinColor;

  /// NEW: overall scene luminance (0..1). Compute this once and pass in.
  /// If null, fallback to skinColor luminance (or default 0.55).
  final double? sceneLuminance;

  /// Anti-jitter smoothing key (use face.trackingId)
  final int faceId;

  // Tuning knobs for cheek anchor positioning
  static const double anchorUpFactor = 0.02; // Lift relative to face height
  static const double anchorOutFactor = 0.03; // Move toward temple relative to face width
  static const double anchorInLimitFactor = 0.08; // Max inward movement relative to face width

  BlushPainter({
    required this.face,
    required this.blushColor,
    required this.intensity,
    required this.faceShape,
    this.skinColor,
    this.sceneLuminance,
    this.faceId = -1,
  });

  // -----------------------------
  // #6 Anti-jitter smoothing (EMA)
  // -----------------------------
  static final Map<int, List<ui.Offset>> _ovalSmoothers = <int, List<ui.Offset>>{};
  static final Map<int, ui.Offset> _leftAnchorSmoothers = <int, ui.Offset>{};
  static final Map<int, ui.Offset> _rightAnchorSmoothers = <int, ui.Offset>{};

  // TASK A: Fix smoothing key generation
  int _faceKey() => (faceId == -1) ? face.boundingBox.hashCode : faceId;

  void paint(Canvas canvas, Size size) {
    final k0 = intensity.clamp(0.0, 1.0);
    if (k0 <= 0.0) return;

    final box = face.boundingBox;
    final faceW = box.width;
    final faceH = box.height;

    // Face-shape tuning
    double cheekYFactor;
    double lift;
    double widthFactor;
    double inwardFactor;

    switch (faceShape) {
      case FaceShape.round:
        cheekYFactor = 0.58;
        lift = 1.22;
        widthFactor = 1.10;
        inwardFactor = 1.06;
        break;
      case FaceShape.square:
        cheekYFactor = 0.64;
        lift = 0.92;
        widthFactor = 0.98;
        inwardFactor = 0.96;
        break;
      case FaceShape.oval:
        cheekYFactor = 0.62;
        lift = 1.06;
        widthFactor = 1.02;
        inwardFactor = 1.00;
        break;
      case FaceShape.heart:
        cheekYFactor = 0.60;
        lift = 1.14;
        widthFactor = 1.00;
        inwardFactor = 1.03;
        break;
      case FaceShape.unknown:
        cheekYFactor = 0.62;
        lift = 1.0;
        widthFactor = 1.0;
        inwardFactor = 1.0;
        break;
    }

    // #4 Tone adaptation (auto-visibility boost from skin/blush tone)
    final autoBoost = _computeAutoBoost(blush: blushColor, skin: skinColor);

    // ✅ Lighting Awareness Boost
    // TASK C: Now using properly passed sceneLuminance
    final l = (sceneLuminance ?? (skinColor != null ? _luminance01(skinColor!) : 0.55)).clamp(0.0, 1.0);
    final lightingBoost = (l < 0.35)
        ? ui.lerpDouble(1.20, 1.00, (l / 0.35).clamp(0.0, 1.0))!
        : (l > 0.75)
            ? ui.lerpDouble(1.00, 0.90, ((l - 0.75) / 0.25).clamp(0.0, 1.0))!
            : 1.00;

    final k = (k0 * autoBoost * lightingBoost).clamp(0.0, 1.0);

    // Scale-aware feathering (consistent look across face sizes)
    final sigmaBase = max(faceW, faceH) * 0.012;
    final sigmaSoft = sigmaBase * 2.0;
    final sigmaFeather = sigmaBase * 3.3;
    final sigmaDiffuse = sigmaBase * 4.4;

    // Landmark-based placement
    final leftCheekPts = _contourOffsets(face.contours[FaceContourType.leftCheek]?.points);
    final rightCheekPts = _contourOffsets(face.contours[FaceContourType.rightCheek]?.points);

    // Face oval (for clipping + fallback placement)
    final faceOvalPts = _contourOffsets(face.contours[FaceContourType.face]?.points);

    if (faceOvalPts.length < 10) {
      _fallbackBlush(
        canvas: canvas,
        box: box,
        faceW: faceW,
        faceH: faceH,
        cheekYFactor: cheekYFactor,
        lift: lift,
        widthFactor: widthFactor,
        k: k,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
      );
      return;
    }

    // Smooth face oval points (#6 anti-jitter)
    final baseKey = _faceKey(); // TASK A: Use fixed key
    final smoothedOval = _smoothPoints(faceOvalPts, baseKey, alpha: 0.18);

    // #5 No-paint zone masking
    final faceClip = _buildSmoothClosedPath(smoothedOval, targetPoints: 42);

    final eyeL = _contourOffsets(face.contours[FaceContourType.leftEye]?.points);
    final eyeR = _contourOffsets(face.contours[FaceContourType.rightEye]?.points);
    final upperLip = _contourOffsets(face.contours[FaceContourType.upperLipTop]?.points);
    final lowerLip = _contourOffsets(face.contours[FaceContourType.lowerLipBottom]?.points);
    // FIX B: Get eyebrow contours if available
    final leftEyebrow = _contourOffsets(face.contours[FaceContourType.leftEyebrowTop]?.points);
    final rightEyebrow = _contourOffsets(face.contours[FaceContourType.rightEyebrowTop]?.points);

    final exclude = Path();

    // FIX B: Inflate eye exclusion zones
    if (eyeL.length >= 5) {
      final eyeBounds = _boundsOf(eyeL).inflate(faceW * 0.08); // Bigger safety zone
      exclude.addOval(eyeBounds);
    }
    if (eyeR.length >= 5) {
      final eyeBounds = _boundsOf(eyeR).inflate(faceW * 0.08); // Bigger safety zone
      exclude.addOval(eyeBounds);
    }
    
    // FIX B: Add eyebrow exclusion zones
    if (leftEyebrow.isNotEmpty) {
      final browBounds = _boundsOf(leftEyebrow).inflate(faceW * 0.04);
      exclude.addOval(browBounds);
    }
    if (rightEyebrow.isNotEmpty) {
      final browBounds = _boundsOf(rightEyebrow).inflate(faceW * 0.04);
      exclude.addOval(browBounds);
    }
    
    if (upperLip.length >= 5 && lowerLip.length >= 5) {
      exclude.addPath(_buildSmoothClosedPath(upperLip, targetPoints: 22), ui.Offset.zero);
      exclude.addPath(_buildSmoothClosedPath(lowerLip, targetPoints: 22), ui.Offset.zero);
    }

    // Nose bridge small exclusion zone
    final noseBridge = _contourOffsets(face.contours[FaceContourType.noseBridge]?.points);
    if (noseBridge.length >= 2) {
      final nb = _boundsOf(noseBridge).inflate(faceW * 0.03);
      exclude.addRRect(RRect.fromRectXY(nb, 18, 18));
    }

    final clip = Path.combine(PathOperation.difference, faceClip, exclude);

    canvas.save();
    canvas.clipPath(clip);

    // Nose center bias to keep blush stable on yaw
    final noseCenterX = _estimateNoseCenterX(face, box);

    // Calculate cheek anchors for both sides
    final leftAnchor = _computeCheekAnchor(
      isLeft: true,
      box: box,
      faceW: faceW,
      faceH: faceH,
      eyeContour: eyeL,
      faceOval: smoothedOval,
      noseCenterX: noseCenterX,
      cheekYFactor: cheekYFactor, // FIX A: Pass cheekYFactor
      faceKey: baseKey,
    );

    final rightAnchor = _computeCheekAnchor(
      isLeft: false,
      box: box,
      faceW: faceW,
      faceH: faceH,
      eyeContour: eyeR,
      faceOval: smoothedOval,
      noseCenterX: noseCenterX,
      cheekYFactor: cheekYFactor, // FIX A: Pass cheekYFactor
      faceKey: baseKey,
    );

    if (leftCheekPts.length >= 5 && rightCheekPts.length >= 5) {
      _drawCheekFromContour(
        canvas: canvas,
        box: box,
        faceW: faceW,
        faceH: faceH,
        cheekContour: leftCheekPts,
        left: true,
        cheekYFactor: cheekYFactor,
        lift: lift,
        widthFactor: widthFactor,
        inwardFactor: inwardFactor,
        k: k,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
        sigmaDiffuse: sigmaDiffuse,
        noseCenterX: noseCenterX,
        cheekAnchor: leftAnchor,
        faceKey: baseKey,
      );

      _drawCheekFromContour(
        canvas: canvas,
        box: box,
        faceW: faceW,
        faceH: faceH,
        cheekContour: rightCheekPts,
        left: false,
        cheekYFactor: cheekYFactor,
        lift: lift,
        widthFactor: widthFactor,
        inwardFactor: inwardFactor,
        k: k,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
        sigmaDiffuse: sigmaDiffuse,
        noseCenterX: noseCenterX,
        cheekAnchor: rightAnchor,
        faceKey: baseKey,
      );
    } else {
      _drawCheekFromFaceOvalBand(
        canvas: canvas,
        faceOval: smoothedOval,
        box: box,
        cheekYFactor: cheekYFactor,
        lift: lift,
        widthFactor: widthFactor,
        inwardFactor: inwardFactor,
        k: k,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
        sigmaDiffuse: sigmaDiffuse,
        left: true,
        noseCenterX: noseCenterX,
        cheekAnchor: leftAnchor,
      );

      _drawCheekFromFaceOvalBand(
        canvas: canvas,
        faceOval: smoothedOval,
        box: box,
        cheekYFactor: cheekYFactor,
        lift: lift,
        widthFactor: widthFactor,
        inwardFactor: inwardFactor,
        k: k,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
        sigmaDiffuse: sigmaDiffuse,
        left: false,
        noseCenterX: noseCenterX,
        cheekAnchor: rightAnchor,
      );
    }

    canvas.restore();
  }

  // ----------------------------------------------------------
  // #2 Multi-gradient shape realism + #3 Blend mode layering
  // ----------------------------------------------------------
  void _renderLayeredBlush({
    required Canvas canvas,
    required Path region,
    required ui.Offset center, // Now using cheekAnchor as center
    required double radius,
    required Rect saveBounds,
    required double k,
    required double sigmaSoft,
    required double sigmaFeather,
    required double sigmaDiffuse,
    required bool left,
  }) {
    final base = blushColor;

    // Slight HSL tuning for realism
    final core = _shiftHsl(base, hueDelta: 4.0, satMul: 1.10, lightMul: 0.98);
    final edge = _shiftHsl(base, hueDelta: 6.0, satMul: 0.88, lightMul: 1.06);

    // Directional lift gradient (toward temple)
    final dir = left ? const ui.Offset(-1, -1) : const ui.Offset(1, -1);
    final liftA = center + dir * (radius * 0.45);
    final liftB = center - dir * (radius * 0.55);

    final liftShader = ui.Gradient.linear(
      liftA,
      liftB,
      [
        Colors.white.withOpacity(0.06 * k),
        Colors.transparent,
      ],
      const [0.0, 1.0],
    );

    final baseShader = ui.Gradient.radial(
      center,
      radius,
      [
        core.withOpacity(0.52 * k),
        base.withOpacity(0.18 * k),
        edge.withOpacity(0.0),
      ],
      const [0.0, 0.72, 1.0],
    );

    final featherShader = ui.Gradient.radial(
      center,
      radius * 1.25,
      [
        base.withOpacity(0.14 * k),
        base.withOpacity(0.05 * k),
        Colors.transparent,
      ],
      const [0.0, 0.72, 1.0],
    );

    canvas.saveLayer(saveBounds, Paint());

    // PASS 1: soft embedded pigment
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..shader = baseShader
        ..blendMode = BlendMode.softLight
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft),
    );

    // PASS 2: deepen (shadow depth)
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(
          center,
          radius * 0.95,
          [
            base.withOpacity(0.10 * k),
            Colors.transparent,
          ],
          const [0.0, 1.0],
        )
        ..blendMode = BlendMode.multiply
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft * 0.95),
    );

    // PASS 3: pigment core pop (contrast)
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(
          center,
          radius * 0.62,
          [
            core.withOpacity(0.26 * k),
            Colors.transparent,
          ],
          const [0.0, 1.0],
        )
        ..blendMode = BlendMode.overlay
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft * 0.85),
    );

    // PASS 4: feather edges
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..shader = featherShader
        ..blendMode = BlendMode.softLight
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaFeather),
    );

    // PASS 5: diffuse haze
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..color = base.withOpacity(0.028 * k)
        ..blendMode = BlendMode.softLight
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaDiffuse),
    );

    // PASS 6: subtle highlight lift (toward temple)
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..shader = liftShader
        ..blendMode = BlendMode.screen
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft * 1.1),
    );

    canvas.restore();
  }

  void _drawCheekFromContour({
    required Canvas canvas,
    required Rect box,
    required double faceW,
    required double faceH,
    required List<ui.Offset> cheekContour,
    required bool left,
    required double cheekYFactor,
    required double lift,
    required double widthFactor,
    required double inwardFactor,
    required double k,
    required double sigmaSoft,
    required double sigmaFeather,
    required double sigmaDiffuse,
    required double noseCenterX,
    required ui.Offset cheekAnchor, // New: pre-computed cheek anchor
    required int faceKey, // TASK A: Use fixed key
  }) {
    if (cheekContour.length < 5) return;

    final cheekKey = faceKey * 100 + (left ? 1 : 2); // TASK A: Fixed key
    final cheek = _smoothPoints(cheekContour, cheekKey, alpha: 0.22);

    final sideSign = left ? -1.0 : 1.0;
    final noseBias = ((box.center.dx - noseCenterX) / max(1.0, faceW)).clamp(-0.18, 0.18);
    final biasX = noseBias * faceW * 0.18 * sideSign;

    final inward = faceW * 0.11 * widthFactor * inwardFactor;
    final liftY = faceH * 0.035 * lift;
    final dirXToCenter = left ? 1.0 : -1.0;

    cheek.sort((a, b) => a.dy.compareTo(b.dy));
    final targetY = box.top + faceH * cheekYFactor;
    final bandTop = targetY - faceH * 0.10;
    final bandBot = targetY + faceH * 0.11;

    final band = cheek.where((p) => p.dy >= bandTop && p.dy <= bandBot).toList();
    final outer = _resample(band.isNotEmpty ? band : cheek, 12);

    final inner = outer.map((p) {
      final px = p.dx + biasX;
      return ui.Offset(px + inward * dirXToCenter, p.dy - liftY);
    }).toList();

    final region = _buildRegionFromOuterInner(outer, inner);

    // Use cheekAnchor as center instead of average
    var center = cheekAnchor;
    
    // FIX C: Reduce radius if anchor is too high
    var radius = faceW * 0.22 * widthFactor;
    final tooHigh = center.dy < box.top + faceH * 0.45;
    if (tooHigh) {
      radius *= 0.75; // Reduce radius when too close to eyes
    }
    
    final saveBounds = region.getBounds().inflate(radius * 0.70);

    _renderLayeredBlush(
      canvas: canvas,
      region: region,
      center: center,
      radius: radius,
      saveBounds: saveBounds,
      k: k,
      sigmaSoft: sigmaSoft,
      sigmaFeather: sigmaFeather,
      sigmaDiffuse: sigmaDiffuse,
      left: left,
    );
  }

  void _drawCheekFromFaceOvalBand({
    required Canvas canvas,
    required List<ui.Offset> faceOval,
    required Rect box,
    required double cheekYFactor,
    required double lift,
    required double widthFactor,
    required double inwardFactor,
    required double k,
    required double sigmaSoft,
    required double sigmaFeather,
    required double sigmaDiffuse,
    required bool left,
    required double noseCenterX,
    required ui.Offset cheekAnchor, // New: pre-computed cheek anchor
  }) {
    final faceW = box.width;
    final faceH = box.height;

    final sidePts = faceOval.where((p) => left ? (p.dx <= box.center.dx) : (p.dx >= box.center.dx)).toList();
    if (sidePts.length < 6) return;

    sidePts.sort((a, b) => a.dy.compareTo(b.dy));

    final targetY = box.top + faceH * cheekYFactor;
    final bandTop = targetY - faceH * 0.10;
    final bandBot = targetY + faceH * 0.11;

    final band = sidePts.where((p) => p.dy >= bandTop && p.dy <= bandBot).toList();
    final outer = _resample(band.length >= 6 ? band : sidePts, 12);

    final sideSign = left ? -1.0 : 1.0;
    final noseBias = ((box.center.dx - noseCenterX) / max(1.0, faceW)).clamp(-0.18, 0.18);
    final biasX = noseBias * faceW * 0.22 * sideSign;

    final inward = faceW * 0.12 * widthFactor * inwardFactor;
    final liftY = faceH * 0.04 * lift;
    final dirXToCenter = left ? 1.0 : -1.0;

    final inner = outer.map((p) {
      final px = p.dx + biasX;
      return ui.Offset(px + inward * dirXToCenter, p.dy - liftY);
    }).toList();

    final region = _buildRegionFromOuterInner(outer, inner);

    // Use cheekAnchor as center instead of average
    var center = cheekAnchor;
    
    // FIX C: Reduce radius if anchor is too high
    var radius = faceW * 0.24 * widthFactor;
    final tooHigh = center.dy < box.top + faceH * 0.45;
    if (tooHigh) {
      radius *= 0.75; // Reduce radius when too close to eyes
    }
    
    final saveBounds = region.getBounds().inflate(radius * 0.70);

    _renderLayeredBlush(
      canvas: canvas,
      region: region,
      center: center,
      radius: radius,
      saveBounds: saveBounds,
      k: k,
      sigmaSoft: sigmaSoft,
      sigmaFeather: sigmaFeather,
      sigmaDiffuse: sigmaDiffuse,
      left: left,
    );
  }

  void _fallbackBlush({
    required Canvas canvas,
    required Rect box,
    required double faceW,
    required double faceH,
    required double cheekYFactor,
    required double lift,
    required double widthFactor,
    required double k,
    required double sigmaSoft,
    required double sigmaFeather,
  }) {
    void draw(bool left) {
      final cx = left ? (box.left + faceW * 0.30) : (box.left + faceW * 0.70);
      final cy = box.top + faceH * cheekYFactor;

      final patchW = faceW * 0.28 * widthFactor;
      final patchH = faceH * 0.15;

      final tilt = left ? -1.0 : 1.0;
      final dxTemple = faceW * 0.12 * tilt * lift;
      final dyTemple = -faceH * 0.065 * lift;

      final p1 = ui.Offset(cx - patchW * 0.50, cy + patchH * 0.20);
      final p2 = ui.Offset(cx + patchW * 0.22, cy - patchH * 0.24);
      final p3 = ui.Offset(cx + dxTemple, cy + dyTemple);

      final region = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(p2.dx, p2.dy, p3.dx, p3.dy)
        ..quadraticBezierTo(cx, cy + patchH * 0.40, p1.dx, p1.dy)
        ..close();

      final r = max(patchW, patchH) * 1.10;
      final saveBounds = region.getBounds().inflate(r * 0.55);

      _renderLayeredBlush(
        canvas: canvas,
        region: region,
        center: ui.Offset(cx, cy),
        radius: r,
        saveBounds: saveBounds,
        k: k,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
        sigmaDiffuse: sigmaFeather * 1.3,
        left: left,
      );
    }

    draw(true);
    draw(false);
  }

  // -----------------------------
  // CHEEK ANCHOR FUNCTION (IMPROVED WITH ALL FIXES)
  // -----------------------------
  ui.Offset _computeCheekAnchor({
    required bool isLeft,
    required Rect box,
    required double faceW,
    required double faceH,
    required List<ui.Offset> eyeContour,
    required List<ui.Offset> faceOval,
    required double noseCenterX,
    required double cheekYFactor, // FIX A: Added cheekYFactor parameter
    required int faceKey, // TASK A: Use fixed key
  }) {
    ui.Offset startPoint;
    
    // FIX A: Calculate target cheek Y
    final targetCheekY = box.top + faceH * cheekYFactor;
    final minY = targetCheekY - 0.06 * faceH; // Slightly above cheek band
    final maxY = targetCheekY + 0.02 * faceH; // Slightly below cheek band
    
    if (eyeContour.isNotEmpty) {
      // TASK B: Improved outer eye corner selection
      // Find eye bounds and vertical center
      double minX = eyeContour.first.dx, maxX = eyeContour.first.dx;
      double minYEye = eyeContour.first.dy, maxYEye = eyeContour.first.dy;
      
      for (final p in eyeContour.skip(1)) {
        minX = min(minX, p.dx);
        maxX = max(maxX, p.dx);
        minYEye = min(minYEye, p.dy);
        maxYEye = max(maxYEye, p.dy);
      }
      
      final eyeCenterY = (minYEye + maxYEye) / 2;
      final searchWidth = (maxX - minX) * 0.3; // Look at outer 30% of eye width
      
      List<ui.Offset> outerCandidates = [];
      
      if (isLeft) {
        // Left eye: look at leftmost points
        final leftBoundary = minX + searchWidth;
        outerCandidates = eyeContour.where((p) => p.dx <= leftBoundary).toList();
      } else {
        // Right eye: look at rightmost points
        final rightBoundary = maxX - searchWidth;
        outerCandidates = eyeContour.where((p) => p.dx >= rightBoundary).toList();
      }
      
      if (outerCandidates.isNotEmpty) {
        // Pick the candidate closest to vertical center
        outerCandidates.sort((a, b) {
          final diffA = (a.dy - eyeCenterY).abs();
          final diffB = (b.dy - eyeCenterY).abs();
          return diffA.compareTo(diffB);
        });
        startPoint = outerCandidates.first;
      } else {
        // Fallback to original method
        startPoint = eyeContour.reduce((a, b) {
          if (isLeft) {
            return a.dx < b.dx ? a : b;
          } else {
            return a.dx > b.dx ? a : b;
          }
        });
      }
    } else {
      // Fallback: use face oval side midpoint, but adjusted to cheek zone
      final sidePts = faceOval.where((p) => isLeft ? (p.dx <= box.center.dx) : (p.dx >= box.center.dx)).toList();
      if (sidePts.isNotEmpty) {
        // FIX A: Find points in the cheek zone
        final cheekZonePts = sidePts.where((p) => p.dy >= minY && p.dy <= maxY).toList();
        if (cheekZonePts.isNotEmpty) {
          // Pick the outermost point in cheek zone
          cheekZonePts.sort((a, b) => isLeft ? a.dx.compareTo(b.dx) : b.dx.compareTo(a.dx));
          startPoint = cheekZonePts.first;
        } else {
          // Fallback to original midpoint but clamp Y
          sidePts.sort((a, b) => a.dy.compareTo(b.dy));
          final midIdx = sidePts.length ~/ 2;
          startPoint = sidePts[midIdx];
        }
      } else {
        // Ultimate fallback - use target cheek Y
        startPoint = ui.Offset(
          isLeft ? box.left + faceW * 0.25 : box.right - faceW * 0.25,
          targetCheekY,
        );
      }
    }

    // Apply tuning knobs
    final liftY = -faceH * anchorUpFactor; // Lift up
    final outX = isLeft ? -faceW * anchorOutFactor : faceW * anchorOutFactor; // Move toward temple
    
    // Calculate proposed anchor
    var anchor = ui.Offset(
      startPoint.dx + outX,
      startPoint.dy + liftY,
    );

    // FIX A: Clamp Y to cheek band
    anchor = ui.Offset(
      anchor.dx,
      anchor.dy.clamp(minY, maxY),
    );

    // Prevent going too close to nose
    final maxInward = faceW * anchorInLimitFactor;
    if (isLeft) {
      final distanceFromNose = noseCenterX - anchor.dx;
      if (distanceFromNose < maxInward) {
        anchor = ui.Offset(noseCenterX - maxInward, anchor.dy);
      }
    } else {
      final distanceFromNose = anchor.dx - noseCenterX;
      if (distanceFromNose < maxInward) {
        anchor = ui.Offset(noseCenterX + maxInward, anchor.dy);
      }
    }

    // Apply smoothing
    final smootherKey = faceKey * 1000 + (isLeft ? 1 : 2); // TASK A: Fixed key
    final smoothers = isLeft ? _leftAnchorSmoothers : _rightAnchorSmoothers;
    final prevAnchor = smoothers[smootherKey];
    
    if (prevAnchor == null) {
      smoothers[smootherKey] = anchor;
    } else {
      // EMA smoothing for stability
      final smoothed = ui.Offset(
        prevAnchor.dx + (anchor.dx - prevAnchor.dx) * 0.25,
        prevAnchor.dy + (anchor.dy - prevAnchor.dy) * 0.25,
      );
      smoothers[smootherKey] = smoothed;
      anchor = smoothed;
    }

    return anchor;
  }

  // -----------------------------
  // Helpers
  // -----------------------------
  List<ui.Offset> _contourOffsets(List<Point<int>>? pts) {
    if (pts == null || pts.isEmpty) return const [];
    return pts.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
  }

  double _computeAutoBoost({required Color blush, required Color? skin}) {
    final blushL = _luminance01(blush);
    final blushSat = _saturation01(blush);

    double skinL = 0.55;
    if (skin != null) skinL = _luminance01(skin);

    final skinBrightBoost =
        ui.lerpDouble(1.0, 1.22, ((skinL - 0.52) / 0.30).clamp(0.0, 1.0))!;
    final blushLightBoost =
        ui.lerpDouble(1.0, 1.28, ((blushL - 0.55) / 0.35).clamp(0.0, 1.0))!;
    final lowSatBoost =
        ui.lerpDouble(1.0, 1.18, ((0.38 - blushSat) / 0.38).clamp(0.0, 1.0))!;

    return (skinBrightBoost * blushLightBoost * lowSatBoost).clamp(1.0, 1.45);
  }

  double _luminance01(Color c) {
    final r = c.red / 255.0;
    final g = c.green / 255.0;
    final b = c.blue / 255.0;
    return (0.2126 * r + 0.7152 * g + 0.0722 * b).clamp(0.0, 1.0);
  }

  double _saturation01(Color c) {
    final r = c.red / 255.0;
    final g = c.green / 255.0;
    final b = c.blue / 255.0;
    final maxV = max(r, max(g, b));
    final minV = min(r, min(g, b));
    final delta = maxV - minV;
    if (maxV <= 0.0001) return 0.0;
    return (delta / maxV).clamp(0.0, 1.0);
  }

  Color _shiftHsl(Color c, {double hueDelta = 0, double satMul = 1.0, double lightMul = 1.0}) {
    final hsl = HSLColor.fromColor(c);
    final h = (hsl.hue + hueDelta) % 360.0;
    final s = (hsl.saturation * satMul).clamp(0.0, 1.0);
    final l = (hsl.lightness * lightMul).clamp(0.0, 1.0);
    return hsl.withHue(h).withSaturation(s).withLightness(l).toColor();
  }

  double _estimateNoseCenterX(Face face, Rect box) {
    final noseBottom = face.contours[FaceContourType.noseBottom]?.points;
    if (noseBottom != null && noseBottom.isNotEmpty) {
      double sx = 0;
      for (final p in noseBottom) {
        sx += p.x.toDouble();
      }
      return sx / noseBottom.length;
    }
    return box.center.dx;
  }

  Path _buildSmoothClosedPath(List<ui.Offset> pts, {required int targetPoints}) {
    final s = _resample(pts, targetPoints);
    final path = Path()..moveTo(s.first.dx, s.first.dy);
    _addSmoothCurve(path, s, closed: true);
    path.close();
    return path;
  }

  Path _buildRegionFromOuterInner(List<ui.Offset> outer, List<ui.Offset> inner) {
    final region = Path();
    region.moveTo(outer.first.dx, outer.first.dy);
    _addSmoothCurve(region, outer, closed: false);
    for (int i = inner.length - 1; i >= 0; i--) {
      region.lineTo(inner[i].dx, inner[i].dy);
    }
    region.close();
    return region;
  }

  void _addSmoothCurve(Path path, List<ui.Offset> pts, {bool closed = false}) {
    if (pts.length < 3) {
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      return;
    }

    final n = pts.length;
    for (int i = 0; i < n - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mid = ui.Offset((p0.dx + p1.dx) * 0.5, (p0.dy + p1.dy) * 0.5);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }

    if (closed) {
      final pLast = pts[n - 1];
      final pFirst = pts[0];
      final mid = ui.Offset((pLast.dx + pFirst.dx) * 0.5, (pLast.dy + pFirst.dy) * 0.5);
      path.quadraticBezierTo(pLast.dx, pLast.dy, mid.dx, mid.dy);
    } else {
      path.lineTo(pts.last.dx, pts.last.dy);
    }
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

  ui.Offset _average(List<ui.Offset> pts) {
    double sx = 0, sy = 0;
    for (final p in pts) {
      sx += p.dx;
      sy += p.dy;
    }
    return ui.Offset(sx / pts.length, sy / pts.length);
  }

  Rect _boundsOf(List<ui.Offset> pts) {
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts.skip(1)) {
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  // EMA smoothing for point list
  List<ui.Offset> _smoothPoints(List<ui.Offset> pts, int key, {double alpha = 0.18}) {
    final prev = _ovalSmoothers[key];
    if (prev == null || prev.length != pts.length) {
      _ovalSmoothers[key] = List<ui.Offset>.from(pts);
      return pts;
    }
    final out = <ui.Offset>[];
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      final q = prev[i];
      out.add(ui.Offset(
        q.dx + (p.dx - q.dx) * alpha,
        q.dy + (p.dy - q.dy) * alpha,
      ));
    }
    _ovalSmoothers[key] = out;
    return out;
  }
}
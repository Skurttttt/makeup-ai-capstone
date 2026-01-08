import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'look_engine.dart'; // for FaceShape

// ✅ 1) Add enum at the top of file
enum LipFinish { matte, glossy }

class MakeupOverlayPainter extends CustomPainter {
  final ui.Image image;
  final Face face;

  final Color lipstickColor;
  final Color blushColor;
  final Color eyeshadowColor;

  /// 0.0–1.0 user intensity slider
  final double intensity;

  /// For face-shape-aware placement
  final FaceShape faceShape;

  // ✅ 2) Add field
  final LipFinish lipFinish;

  MakeupOverlayPainter({
    required this.image,
    required this.face,
    required this.lipstickColor,
    required this.blushColor,
    required this.eyeshadowColor,
    required this.intensity,
    required this.faceShape,
    // ✅ 2) Add to constructor with default value
    this.lipFinish = LipFinish.glossy,
  });

  // ---------- EYELINER HELPERS ----------
  Path _catmullRomToBezierPath(List<ui.Offset> pts, {double tension = 0.5}) {
    if (pts.length < 2) return Path();

    // Clamp tension: 0..1
    final t = tension.clamp(0.0, 1.0);

    // Duplicate endpoints for boundary conditions
    ui.Offset p(int i) {
      if (i < 0) return pts.first;
      if (i >= pts.length) return pts.last;
      return pts[i];
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);

    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = p(i - 1);
      final p1 = p(i);
      final p2 = p(i + 1);
      final p3 = p(i + 2);

      // Catmull-Rom to Bezier conversion
      final c1 = ui.Offset(
        p1.dx + (p2.dx - p0.dx) * (t / 6.0),
        p1.dy + (p2.dy - p0.dy) * (t / 6.0),
      );
      final c2 = ui.Offset(
        p2.dx - (p3.dx - p1.dx) * (t / 6.0),
        p2.dy - (p3.dy - p1.dy) * (t / 6.0),
      );

      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    return path;
  }

  List<ui.Offset> _upperLidPoints(List<ui.Offset> eyePts) {
    // Split points into upper half using midpoint Y
    double minY = eyePts.first.dy, maxY = eyePts.first.dy;
    double minX = eyePts.first.dx, maxX = eyePts.first.dx;

    for (final p in eyePts.skip(1)) {
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
    }

    final centerY = (minY + maxY) / 2.0;

    // Upper lid = points above centerY
    final upper = eyePts.where((p) => p.dy <= centerY).toList();
    if (upper.length < 3) return [];

    // Keep only points that are roughly on the lid (removes weird jumps)
    upper.sort((a, b) => a.dx.compareTo(b.dx));

    // Light downsample to reduce jitter (keeps shape)
    final filtered = <ui.Offset>[];
    for (int i = 0; i < upper.length; i++) {
      if (i == 0 || i == upper.length - 1 || i % 2 == 0) {
        filtered.add(upper[i]);
      }
    }

    return filtered;
  }

  double _eyeOpennessRatio(List<ui.Offset> eyePts) {
    double minY = eyePts.first.dy, maxY = eyePts.first.dy;
    double minX = eyePts.first.dx, maxX = eyePts.first.dx;
    for (final p in eyePts.skip(1)) {
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
    }
    final w = max(1.0, maxX - minX);
    final h = max(1.0, maxY - minY);
    return h / w; // bigger = more open
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());

    // Clamp intensity
    final k = intensity.clamp(0.0, 1.0);

    List<ui.Offset>? contourPoints(FaceContourType type) {
      final pts = face.contours[type]?.points;
      if (pts == null || pts.length < 3) return null;
      return pts.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
    }

    ui.Rect boundsOf(List<ui.Offset> pts) {
      double minX = pts.first.dx, maxX = pts.first.dx;
      double minY = pts.first.dy, maxY = pts.first.dy;
      for (final p in pts.skip(1)) {
        minX = min(minX, p.dx);
        maxX = max(maxX, p.dx);
        minY = min(minY, p.dy);
        maxY = max(maxY, p.dy);
      }
      return ui.Rect.fromLTRB(minX, minY, maxX, maxY);
    }

    Path pathFromPoints(List<ui.Offset> pts, {bool close = true}) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      if (close) path.close();
      return path;
    }

    // ✅ 4) Replace the whole lipstick section with this COMPLETE block
    // ---------------------------
    // 1) LIPSTICK (Natural Gradient + Texture)
    // - darker inside, softer edges
    // - matte grain OR glossy shine
    // ---------------------------

    void drawLipNatural(FaceContourType t) {
      final pts = contourPoints(t);
      if (pts == null) return;

      final lipPath = pathFromPoints(pts);
      final rect = boundsOf(pts);

      // A) Base soft fill
      final basePaint = Paint()
        ..color = lipstickColor.withOpacity(0.30 * k)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawPath(lipPath, basePaint);

      // B) Inner depth gradient (darker center, soft edges)
      final innerShader = ui.Gradient.radial(
        rect.center,
        (rect.width + rect.height) * 0.55,
        [
          // darker inside
          Color.lerp(Colors.black, lipstickColor, 0.78)!.withOpacity(0.55 * k),
          lipstickColor.withOpacity(0.28 * k),
          lipstickColor.withOpacity(0.10 * k),
          lipstickColor.withOpacity(0.0),
        ],
        [0.0, 0.45, 0.78, 1.0],
      );

      final innerPaint = Paint()
        ..shader = innerShader
        ..blendMode = BlendMode.multiply
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);

      canvas.drawPath(lipPath, innerPaint);

      // C) Edge feathering (removes polygon edges)
      final edgePaint = Paint()
        ..color = lipstickColor.withOpacity(0.22 * k)
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10)
        ..strokeWidth = (rect.height * 0.25).clamp(3.5, 10.0);

      canvas.drawPath(lipPath, edgePaint);

      // D) Texture simulation — clip to lip path
      canvas.save();
      canvas.clipPath(lipPath);

      if (lipFinish == LipFinish.matte) {
        // Matte = subtle grain (very light)
        final rand = Random(1337 + rect.left.round() + rect.top.round());
        final area = rect.width * rect.height;
        final dotCount = (area / 120).clamp(80, 260).toInt();

        for (int i = 0; i < dotCount; i++) {
          final x = rect.left + rand.nextDouble() * rect.width;
          final y = rect.top + rand.nextDouble() * rect.height;

          final r = (0.35 + rand.nextDouble() * 0.85) * k;
          final isLight = rand.nextBool();

          final p = Paint()
            ..color = (isLight ? Colors.white : Colors.black).withOpacity(0.018 * k)
            ..blendMode = BlendMode.overlay
            ..isAntiAlias = true;

          canvas.drawCircle(ui.Offset(x, y), r, p);
        }

        // Powder veil
        final matteVeil = Paint()
          ..color = Colors.white.withOpacity(0.03 * k)
          ..blendMode = BlendMode.softLight
          ..isAntiAlias = true
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);

        canvas.drawRect(rect.inflate(2), matteVeil);
      } else {
        // Glossy = curved shine + bloom
        final shineStroke = Paint()
          ..color = Colors.white.withOpacity(0.12 * k)
          ..blendMode = BlendMode.screen
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8)
          ..strokeWidth = (rect.height * 0.10).clamp(1.5, 5.0);

        // Shine line 1
        final s1 = Path()
          ..moveTo(rect.left + rect.width * 0.18, rect.top + rect.height * 0.52)
          ..quadraticBezierTo(
            rect.left + rect.width * 0.46,
            rect.top + rect.height * 0.30,
            rect.left + rect.width * 0.78,
            rect.top + rect.height * 0.46,
          );

        // Shine line 2 (smaller)
        final s2 = Path()
          ..moveTo(rect.left + rect.width * 0.22, rect.top + rect.height * 0.68)
          ..quadraticBezierTo(
            rect.left + rect.width * 0.50,
            rect.top + rect.height * 0.52,
            rect.left + rect.width * 0.72,
            rect.top + rect.height * 0.64,
          );

        canvas.drawPath(s1, shineStroke);
        canvas.drawPath(s2, shineStroke);

        // Specular bloom (soft spot highlight)
        final bloom = Paint()
          ..shader = ui.Gradient.radial(
            ui.Offset(rect.left + rect.width * 0.62, rect.top + rect.height * 0.44),
            max(rect.width, rect.height) * 0.55,
            [
              Colors.white.withOpacity(0.10 * k),
              Colors.white.withOpacity(0.0),
            ],
            [0.0, 1.0],
          )
          ..blendMode = BlendMode.screen
          ..isAntiAlias = true
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12);

        canvas.drawRect(rect.inflate(4), bloom);
      }

      canvas.restore();
    }

    // Use the upgraded lip draw for all lip contours
    drawLipNatural(FaceContourType.upperLipTop);
    drawLipNatural(FaceContourType.upperLipBottom);
    drawLipNatural(FaceContourType.lowerLipTop);
    drawLipNatural(FaceContourType.lowerLipBottom);

    // ---------------------------
    // 2) EYESHADOW (eyelid region)
    // ---------------------------
    void drawEyelidShadow(FaceContourType eyeType) {
      final eyePts = contourPoints(eyeType);
      if (eyePts == null) return;

      final eyeBounds = boundsOf(eyePts);
      final centerY = (eyeBounds.top + eyeBounds.bottom) / 2;
      final upperPts = eyePts.where((p) => p.dy <= centerY).toList();
      if (upperPts.length < 3) return;

      final lift = max(2.0, eyeBounds.height * 0.45);

      final topArc = upperPts.map((p) => ui.Offset(p.dx, p.dy - lift)).toList();
      final bottomArc =
          upperPts.reversed.map((p) => ui.Offset(p.dx, p.dy - eyeBounds.height * 0.12)).toList();

      final eyelidPath = Path()..moveTo(topArc.first.dx, topArc.first.dy);
      for (final p in topArc.skip(1)) {
        eyelidPath.lineTo(p.dx, p.dy);
      }
      for (final p in bottomArc) {
        eyelidPath.lineTo(p.dx, p.dy);
      }
      eyelidPath.close();

      final shaderRect = ui.Rect.fromLTRB(
        eyeBounds.left,
        eyeBounds.top - lift - 2,
        eyeBounds.right,
        eyeBounds.bottom,
      );

      final shader = ui.Gradient.linear(
        ui.Offset(shaderRect.left, shaderRect.top),
        ui.Offset(shaderRect.left, shaderRect.bottom),
        [
          eyeshadowColor.withOpacity(0.55 * k),
          eyeshadowColor.withOpacity(0.12 * k),
        ],
      );

      final shadowPaint = Paint()
        ..shader = shader
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);

      canvas.drawPath(eyelidPath, shadowPaint);
    }

    drawEyelidShadow(FaceContourType.leftEye);
    drawEyelidShadow(FaceContourType.rightEye);

    // ---------------------------
    // 3) EYELINER (UPGRADED VERSION)
    // ---------------------------
    void drawEyeliner(FaceContourType eyeType) {
      final eyePtsRaw = contourPoints(eyeType);
      if (eyePtsRaw == null || eyePtsRaw.length < 6) return;

      final box = face.boundingBox;
      final faceCenterX = box.left + box.width * 0.5;

      // Get upper lid points
      final upper = _upperLidPoints(eyePtsRaw);
      if (upper.length < 4) return;

      // Slightly lift liner up so it doesn't touch the eyeball
      final lift = max(0.8, (box.height * 0.003));
      final upperLifted = upper.map((p) => ui.Offset(p.dx, p.dy - lift)).toList();

      // Build smooth bezier path
      final linerPath = _catmullRomToBezierPath(upperLifted, tension: 0.75);

      // Eye bounds for thickness scaling
      final eyeBounds = boundsOf(eyePtsRaw);
      final openness = _eyeOpennessRatio(eyePtsRaw);

      // Adaptive thickness based on eye size (clamped)
      final baseW = (eyeBounds.height * 0.085).clamp(1.2, 4.2).toDouble();

      // ---------- Tightline blur (blended lash line) ----------
      final blurPaint = Paint()
        ..color = Colors.black.withOpacity(0.18 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW * 2.2
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);

      canvas.drawPath(linerPath, blurPaint);

      // 🪄 Optional: Lash density illusion (subtle lash root darkening)
      final lashShadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.10 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW * 0.9;

      canvas.drawPath(linerPath.shift(const Offset(0, 1)), lashShadowPaint);

      // ---------- Main crisp liner stroke ----------
      final linerPaint = Paint()
        ..color = Colors.black.withOpacity(0.62 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW;

      canvas.drawPath(linerPath, linerPaint);

      // ---------- Wing gating logic ----------
      // 1) Don't add wing if eyes are too closed/squinting
      // Typical openness range varies, but below ~0.16 tends to look closed in MLKit contours
      final allowByOpenness = openness > 0.16;

      // 2) Don't add wing if head is rotated too much
      final yaw = face.headEulerAngleY ?? 0.0;
      final roll = face.headEulerAngleZ ?? 0.0;
      final allowByPose = yaw.abs() < 18 && roll.abs() < 22;

      // 3) Determine true "outer corner" direction using face center
      // Outer corner = farthest from face center in X direction
      ui.Offset outerCorner = upperLifted.first;
      ui.Offset innerCorner = upperLifted.last;

      double bestOuter = -1;
      double bestInner = -1;

      for (final p in upperLifted) {
        final dx = (p.dx - faceCenterX).abs();
        if (dx > bestOuter) {
          bestOuter = dx;
          outerCorner = p;
        }
      }

      for (final p in upperLifted) {
        final dx = (p.dx - faceCenterX).abs();
        // inner corner tends to be closer to face center horizontally
        final inv = 999999 - dx;
        if (inv > bestInner) {
          bestInner = inv;
          innerCorner = p;
        }
      }

      final outwardSign = (outerCorner.dx - faceCenterX).sign;
      if (outwardSign == 0) return;

      // 4) Prevent wrong-direction wing by checking segment direction
      // Use last segment direction along the lid in outward direction
      upperLifted.sort((a, b) => a.dx.compareTo(b.dx));
      final ordered = upperLifted;

      // Pick endpoints based on outwardSign
      final endIdx = outwardSign > 0 ? ordered.length - 1 : 0;
      final prevIdx = outwardSign > 0 ? ordered.length - 2 : 1;

      final end = ordered[endIdx];
      final prev = ordered[prevIdx];

      final lidDir = ui.Offset(end.dx - prev.dx, end.dy - prev.dy);

      // Wing should go outward (same sign as outwardSign)
      final wingDirOutwardOk = lidDir.dx.sign == outwardSign;

      // 5) Optional: only wing if outer corner is not drooping heavily
      // If outer is much lower than inner, wing can look weird
      final droop = (outerCorner.dy - innerCorner.dy);
      final allowByShape = droop < eyeBounds.height * 0.35;

      final allowWing = allowByOpenness && allowByPose && wingDirOutwardOk && allowByShape;

      if (!allowWing) return;

      // ---------- Draw subtle micro-wing ----------
      // Smaller wing for natural realism
      final wingLen = (eyeBounds.width * 0.14).clamp(3.0, 14.0).toDouble();
      final wingUp = (eyeBounds.height * 0.10).clamp(1.5, 10.0).toDouble();

      final wingEnd = ui.Offset(
        end.dx + outwardSign * wingLen,
        end.dy - wingUp,
      );

      final wingPath = Path()
        ..moveTo(end.dx, end.dy)
        ..quadraticBezierTo(
          end.dx + outwardSign * (wingLen * 0.55),
          end.dy - (wingUp * 0.65),
          wingEnd.dx,
          wingEnd.dy,
        );

      // Wing blur blend first
      final wingBlur = Paint()
        ..color = Colors.black.withOpacity(0.16 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW * 2.0
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);

      canvas.drawPath(wingPath, wingBlur);

      // Then crisp wing
      final wingPaint = Paint()
        ..color = Colors.black.withOpacity(0.60 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW * 0.95;

      canvas.drawPath(wingPath, wingPaint);
    }

    drawEyeliner(FaceContourType.leftEye);
    drawEyeliner(FaceContourType.rightEye);

    // ---------------------------
    // 4) BLUSH (face-shape-aware)
    // ---------------------------
    final box = face.boundingBox;
    final faceW = box.width;
    final faceH = box.height;

    // Face-shape adjustments
    double blushYFactor;
    double blushLift;
    switch (faceShape) {
      case FaceShape.round:
        blushYFactor = 0.58; // higher
        blushLift = 1.25; // more lifted toward temples
        break;
      case FaceShape.square:
        blushYFactor = 0.64; // more apple-centered
        blushLift = 0.85;
        break;
      case FaceShape.oval:
        blushYFactor = 0.62;
        blushLift = 1.05;
        break;
      case FaceShape.heart:
        blushYFactor = 0.60;
        blushLift = 1.10;
        break;
      case FaceShape.unknown:
        blushYFactor = 0.62;
        blushLift = 1.0;
        break;
    }

    void drawBlushPatch({required bool left}) {
      final cheekCenterX = left ? (box.left + faceW * 0.30) : (box.left + faceW * 0.70);
      final cheekCenterY = box.top + faceH * blushYFactor;

      final patchW = faceW * 0.24;
      final patchH = faceH * 0.13;

      final tilt = left ? -1 : 1;
      final dxTemple = faceW * 0.11 * tilt * blushLift;
      final dyTemple = -faceH * 0.06 * blushLift;

      final p1 = ui.Offset(cheekCenterX - patchW * 0.45, cheekCenterY + patchH * 0.18);
      final p2 = ui.Offset(cheekCenterX + patchW * 0.22, cheekCenterY - patchH * 0.22);
      final p3 = ui.Offset(cheekCenterX + dxTemple, cheekCenterY + dyTemple);

      final blushPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(p2.dx, p2.dy, p3.dx, p3.dy)
        ..quadraticBezierTo(cheekCenterX, cheekCenterY + patchH * 0.35, p1.dx, p1.dy)
        ..close();

      final r = max(patchW, patchH) * 0.95;
      final shader = ui.Gradient.radial(
        ui.Offset(cheekCenterX, cheekCenterY),
        r,
        [
          blushColor.withOpacity(0.52 * k),
          blushColor.withOpacity(0.12 * k),
          blushColor.withOpacity(0.0),
        ],
        [0.0, 0.6, 1.0],
      );

      final blushPaint = Paint()
        ..shader = shader
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);

      canvas.drawPath(blushPath, blushPaint);
    }

    drawBlushPatch(left: true);
    drawBlushPatch(left: false);

    // ---------------------------
    // 5) CONTOUR + HIGHLIGHT
    // ---------------------------
    // Contour: cheek hollows + jawline
    // Highlight: nose bridge + top cheekbones

    // a) Nose bridge highlight (vertical soft line)
    final noseCenterX = box.left + faceW * 0.50;
    final noseTopY = box.top + faceH * 0.35;
    final noseBottomY = box.top + faceH * 0.62;

    final noseRect = ui.Rect.fromCenter(
      center: ui.Offset(noseCenterX, (noseTopY + noseBottomY) / 2),
      width: faceW * 0.06,
      height: (noseBottomY - noseTopY),
    );

    final noseHighlight = Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(noseRect.center.dx, noseRect.top),
        ui.Offset(noseRect.center.dx, noseRect.bottom),
        [
          Colors.white.withOpacity(0.35 * k),
          Colors.white.withOpacity(0.05 * k),
        ],
      )
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10)
      ..isAntiAlias = true;

    final nosePath = Path()..addRRect(RRect.fromRectXY(noseRect, 14, 14));
    canvas.drawPath(nosePath, noseHighlight);

    // b) Cheekbone highlight (small soft glow above blush)
    void drawCheekHighlight({required bool left}) {
      final cx = left ? (box.left + faceW * 0.30) : (box.left + faceW * 0.70);
      final cy = box.top + faceH * (blushYFactor - 0.08);

      final rect = ui.Rect.fromCenter(
        center: ui.Offset(cx, cy),
        width: faceW * 0.18,
        height: faceH * 0.06,
      );

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          max(rect.width, rect.height) * 0.7,
          [
            Colors.white.withOpacity(0.30 * k),
            Colors.white.withOpacity(0.0),
          ],
          [0.0, 1.0],
        )
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12)
        ..isAntiAlias = true;

      canvas.drawRect(rect, paint);
    }

    drawCheekHighlight(left: true);
    drawCheekHighlight(left: false);

    // c) Contour cheek hollow (below cheekbone)
    void drawCheekContour({required bool left}) {
      final cx = left ? (box.left + faceW * 0.32) : (box.left + faceW * 0.68);
      final cy = box.top + faceH * 0.70;

      final rect = ui.Rect.fromCenter(
        center: ui.Offset(cx, cy),
        width: faceW * 0.22,
        height: faceH * 0.09,
      );

      final contourPaint = Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          max(rect.width, rect.height),
          [
            Colors.black.withOpacity(0.22 * k),
            Colors.black.withOpacity(0.0),
          ],
          [0.0, 1.0],
        )
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14)
        ..isAntiAlias = true;

      canvas.drawRect(rect, contourPaint);
    }

    drawCheekContour(left: true);
    drawCheekContour(left: false);

    // d) Jawline contour (bottom edges)
    final jawRect = ui.Rect.fromLTRB(
      box.left + faceW * 0.15,
      box.top + faceH * 0.84,
      box.right - faceW * 0.15,
      box.top + faceH * 0.93,
    );

    final jawPaint = Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(jawRect.left, jawRect.center.dy),
        ui.Offset(jawRect.right, jawRect.center.dy),
        [
          Colors.black.withOpacity(0.12 * k),
          Colors.black.withOpacity(0.22 * k),
          Colors.black.withOpacity(0.12 * k),
        ],
        [0.0, 0.5, 1.0],
      )
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18)
      ..isAntiAlias = true;

    canvas.drawRect(jawRect, jawPaint);
  }

  @override
  bool shouldRepaint(covariant MakeupOverlayPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.face != face ||
        oldDelegate.lipstickColor != lipstickColor ||
        oldDelegate.blushColor != blushColor ||
        oldDelegate.eyeshadowColor != eyeshadowColor ||
        oldDelegate.intensity != intensity ||
        oldDelegate.faceShape != faceShape ||
        oldDelegate.lipFinish != lipFinish; // ✅ Add lipFinish check
  }
}
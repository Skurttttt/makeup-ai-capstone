import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'look_engine.dart'; // for FaceShape

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

  MakeupOverlayPainter({
    required this.image,
    required this.face,
    required this.lipstickColor,
    required this.blushColor,
    required this.eyeshadowColor,
    required this.intensity,
    required this.faceShape,
  });

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

    // ---------------------------
    // 1) LIPSTICK (soft fill)
    // ---------------------------
    final lipPaint = Paint()
      ..color = lipstickColor.withOpacity(0.75 * k)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    void drawLip(FaceContourType t) {
      final pts = contourPoints(t);
      if (pts == null) return;
      canvas.drawPath(pathFromPoints(pts), lipPaint);
    }

    drawLip(FaceContourType.upperLipTop);
    drawLip(FaceContourType.upperLipBottom);
    drawLip(FaceContourType.lowerLipTop);
    drawLip(FaceContourType.lowerLipBottom);

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
    // 3) EYELINER (thin line along upper lash)
    // ---------------------------
    void drawEyeliner(FaceContourType eyeType) {
      final eyePts = contourPoints(eyeType);
      if (eyePts == null) return;

      final eyeBounds = boundsOf(eyePts);
      final centerY = (eyeBounds.top + eyeBounds.bottom) / 2;

      // Use upper half points as lash line approximation
      final upperPts = eyePts.where((p) => p.dy <= centerY).toList();
      if (upperPts.length < 3) return;

      // Smooth polyline
      final path = Path()..moveTo(upperPts.first.dx, upperPts.first.dy);
      for (final p in upperPts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }

      final linerPaint = Paint()
        ..color = Colors.black.withOpacity(0.70 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = max(1.2, eyeBounds.height * 0.10);

      canvas.drawPath(path, linerPaint);

      // Small wing
      final last = upperPts.last;
      final wing = ui.Offset(last.dx + eyeBounds.width * 0.18, last.dy - eyeBounds.height * 0.12);
      final wingPath = Path()
        ..moveTo(last.dx, last.dy)
        ..lineTo(wing.dx, wing.dy);

      final wingPaint = Paint()
        ..color = Colors.black.withOpacity(0.70 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..strokeWidth = max(1.0, eyeBounds.height * 0.08);

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
        oldDelegate.faceShape != faceShape;
  }
}

import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'utils.dart';
import 'look_engine.dart';  // Add this import

class EyelinerPainter {
  final Face face;
  final double intensity;

  EyelinerPainter({
    required this.face,
    required this.intensity,
  });

  List<ui.Offset>? _contourPoints(FaceContourType type) {
    final pts = face.contours[type]?.points;
    if (pts == null || pts.length < 3) return null;
    return pts.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
  }

  List<ui.Offset> _upperLidPoints(List<ui.Offset> eyePts) {
    double minY = eyePts.first.dy, maxY = eyePts.first.dy;
    double minX = eyePts.first.dx, maxX = eyePts.first.dx;

    for (final p in eyePts.skip(1)) {
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
    }

    final centerY = (minY + maxY) / 2.0;
    final upper = eyePts.where((p) => p.dy <= centerY).toList();
    if (upper.length < 3) return [];

    upper.sort((a, b) => a.dx.compareTo(b.dx));
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
    return h / w;
  }

  void paint(Canvas canvas, Size size) {
    final k = intensity.clamp(0.0, 1.0);
    if (k == 0) return;

    void drawEyeliner(FaceContourType eyeType) {
      final eyePtsRaw = _contourPoints(eyeType);
      if (eyePtsRaw == null || eyePtsRaw.length < 6) return;

      final box = face.boundingBox;
      final faceCenterX = box.left + box.width * 0.5;

      final upper = _upperLidPoints(eyePtsRaw);
      if (upper.length < 4) return;

      final lift = max(0.8, (box.height * 0.003));
      final upperLifted = upper.map((p) => ui.Offset(p.dx, p.dy - lift)).toList();

      final linerPath = DrawingUtils.catmullRomToBezierPath(upperLifted, tension: 0.75);

      final eyeBounds = DrawingUtils.boundsOf(eyePtsRaw);
      final openness = _eyeOpennessRatio(eyePtsRaw);

      final baseW = (eyeBounds.height * 0.085).clamp(1.2, 4.2).toDouble();

      final blurPaint = Paint()
        ..color = Colors.black.withOpacity(0.18 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW * 2.2
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);

      canvas.drawPath(linerPath, blurPaint);

      final lashShadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.10 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW * 0.9;

      canvas.drawPath(linerPath.shift(const Offset(0, 1)), lashShadowPaint);

      final linerPaint = Paint()
        ..color = Colors.black.withOpacity(0.62 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW;

      canvas.drawPath(linerPath, linerPaint);

      // Wing logic
      final allowByOpenness = openness > 0.16;
      final yaw = face.headEulerAngleY ?? 0.0;
      final roll = face.headEulerAngleZ ?? 0.0;
      final allowByPose = yaw.abs() < 18 && roll.abs() < 22;

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
        final inv = 999999 - dx;
        if (inv > bestInner) {
          bestInner = inv;
          innerCorner = p;
        }
      }

      final outwardSign = (outerCorner.dx - faceCenterX).sign;
      if (outwardSign == 0) return;

      upperLifted.sort((a, b) => a.dx.compareTo(b.dx));
      final ordered = upperLifted;

      final endIdx = outwardSign > 0 ? ordered.length - 1 : 0;
      final prevIdx = outwardSign > 0 ? ordered.length - 2 : 1;

      final end = ordered[endIdx];
      final prev = ordered[prevIdx];

      final lidDir = ui.Offset(end.dx - prev.dx, end.dy - prev.dy);
      final wingDirOutwardOk = lidDir.dx.sign == outwardSign;

      final droop = (outerCorner.dy - innerCorner.dy);
      final allowByShape = droop < eyeBounds.height * 0.35;

      final allowWing = allowByOpenness && allowByPose && wingDirOutwardOk && allowByShape;

      if (!allowWing) return;

      // Draw wing
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

      final wingBlur = Paint()
        ..color = Colors.black.withOpacity(0.16 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW * 2.0
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);

      canvas.drawPath(wingPath, wingBlur);

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
  }
}
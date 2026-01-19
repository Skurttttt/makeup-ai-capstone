// lib/eyeliner_painter.dart
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'utils.dart';
import 'look_engine.dart'; // ✅ 1️⃣ Add EyelinerStyle import

class EyelinerPainter {
  final Face face;
  final double intensity;
  final EyelinerStyle style; // ✅ 2️⃣ Update the EyelinerPainter constructor

  EyelinerPainter({
    required this.face,
    required this.intensity,
    required this.style, // ✅ 2️⃣ Add style parameter
  });

  List<ui.Offset>? _contourPoints(FaceContourType type) {
    final pts = face.contours[type]?.points;
    if (pts == null || pts.length < 3) return null;
    return pts.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
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

    // light downsample to reduce jitter
    final filtered = <ui.Offset>[];
    for (int i = 0; i < upper.length; i++) {
      if (i == 0 || i == upper.length - 1 || i % 2 == 0) filtered.add(upper[i]);
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

  ui.Offset _normalize(ui.Offset v) {
    final len = sqrt(v.dx * v.dx + v.dy * v.dy);
    if (len < 1e-6) return const ui.Offset(1, 0);
    return ui.Offset(v.dx / len, v.dy / len);
  }

  /// ✅ Robust extension that works even if the front camera is mirrored.
  /// eyeOnLeftSideOfImage:
  ///   - true  => outer corner is minX end (index 0)
  ///   - false => outer corner is maxX end (last index)
  List<ui.Offset> _extendUpperLid({
    required List<ui.Offset> upperOrdered,
    required bool eyeOnLeftSideOfImage,
    required Rect eyeBounds,
    required double openness,
  }) {
    if (upperOrdered.length < 4) return upperOrdered;

    final outerIdx = eyeOnLeftSideOfImage ? 0 : (upperOrdered.length - 1);
    final inwardIdx = eyeOnLeftSideOfImage ? 1 : (upperOrdered.length - 2);

    final outer = upperOrdered[outerIdx];
    final inward = upperOrdered[inwardIdx];

    var tangent = ui.Offset(outer.dx - inward.dx, outer.dy - inward.dy);
    tangent = _normalize(tangent);

    final baseExt = (eyeBounds.width * 0.125).clamp(3.2, 14.8);
    final openBoost = ui.lerpDouble(
      0.95,
      1.18,
      ((openness - 0.14) / 0.12).clamp(0.0, 1.0),
    )!;
    final extLen = (baseExt * openBoost).clamp(3.0, 15.0);

    final upBias = ui.Offset(0, -(eyeBounds.height * 0.035).clamp(0.4, 2.2));

    final ext1 = outer + tangent * (extLen * 0.55) + upBias;
    final ext2 = outer + tangent * (extLen * 1.00) + upBias;

    final out = List<ui.Offset>.from(upperOrdered);

    if (eyeOnLeftSideOfImage) {
      out.insert(0, ext2);
      out.insert(0, ext1);
    } else {
      out.add(ext1);
      out.add(ext2);
    }

    return out;
  }

  /// ✅ Draws a path with inner-corner taper (alpha + thickness fade-in).
  /// We do this by stroking small sub-path segments with varying paint.
  void _drawVariableStroke({
    required Canvas canvas,
    required Path path,
    required double baseWidth,
    required double baseAlpha,
    required double innerTaperFrac, // e.g. 0.18 => first 18% fades in
    required bool taperFromStart, // which end is the inner corner
    required Paint Function(double width, double alpha) paintFactory,
    int segments = 42, // higher = smoother taper
  }) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    // Combine metrics length (usually 1 metric, but safe)
    final totalLen = metrics.fold<double>(0, (s, m) => s + m.length);
    if (totalLen <= 1e-6) return;

    // Render in normalized t along total length
    double globalStart = 0.0;

    for (final metric in metrics) {
      final mLen = metric.length;
      if (mLen <= 1e-6) continue;

      for (int i = 0; i < segments; i++) {
        final t0 = i / segments;
        final t1 = (i + 1) / segments;

        final s0 = metric.length * t0;
        final s1 = metric.length * t1;

        // Global normalized position along the entire path
        final g0 = (globalStart + s0) / totalLen;
        final g1 = (globalStart + s1) / totalLen;
        final gMid = (g0 + g1) * 0.5;

        // Determine taper factor near the INNER corner end
        // If taperFromStart=true, inner corner is at t=0; else at t=1.
        final innerT = taperFromStart ? gMid : (1.0 - gMid);

        double taper = 1.0;
        if (innerTaperFrac > 0) {
          final x = (innerT / innerTaperFrac).clamp(0.0, 1.0);
          // Smoothstep
          taper = x * x * (3 - 2 * x);
        }

        final w = max(0.35, baseWidth * (0.25 + 0.75 * taper));
        final a = (baseAlpha * taper).clamp(0.0, 1.0);

        if (a <= 0.001) continue;

        final seg = metric.extractPath(s0, s1);
        final p = paintFactory(w, a);
        canvas.drawPath(seg, p);
      }

      globalStart += mLen;
    }
  }

  void paint(Canvas canvas, Size size) {
    final k = intensity.clamp(0.0, 1.0);
    if (k <= 0.0) return;

    // ✅ 3️⃣ Modify paint method to react to style + intensity
    if (style == EyelinerStyle.none) {
      return; // draw nothing
    }

    double baseWidth = 1.6;
    double wingFactor = 0.0;
    double alpha = 0.7;

    // ✅ 3️⃣ style-aware + opacity-aware configuration
    switch (style) {
      case EyelinerStyle.none:
        return; // already handled above
      case EyelinerStyle.thin:
        baseWidth = 1.2;
        wingFactor = 0.0;
        alpha = 0.6;
        break;
      case EyelinerStyle.subtle:
        baseWidth = 1.8;
        wingFactor = 0.15;
        alpha = 0.75;
        break;
      case EyelinerStyle.emoWing: // ✅ Added for Emo look
        baseWidth = 2.8;
        wingFactor = 0.35;
        alpha = 0.95;
        break;
    }

    final basePaint = Paint()
      ..color = Colors.black.withOpacity(alpha * k)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = baseWidth * k.clamp(0.4, 1.0);

    void drawEyeliner(FaceContourType eyeType) {
      final eyePtsRaw = _contourPoints(eyeType);
      if (eyePtsRaw == null || eyePtsRaw.length < 6) return;

      final faceBox = face.boundingBox;
      final faceCenterX = faceBox.left + faceBox.width * 0.5;

      final eyeBounds = _boundsOf(eyePtsRaw);
      final eyeCenterX = eyeBounds.center.dx;

      // Decide which eye is on which side in IMAGE space (handles mirroring)
      final eyeOnLeftSideOfImage = eyeCenterX < faceCenterX;

      final upper = _upperLidPoints(eyePtsRaw);
      if (upper.length < 4) return;

      final openness = _eyeOpennessRatio(eyePtsRaw);

      // --- Lash adhesion (geometry): sit slightly closer to lash line ---
      final lift = max(0.6, (faceBox.height * 0.0025));
      final settleDown = (eyeBounds.height * 0.013).clamp(0.4, 1.4);
      final upperLifted = upper
          .map((p) => ui.Offset(p.dx, p.dy - lift + settleDown))
          .toList();

      final ordered = List<ui.Offset>.from(upperLifted)
        ..sort((a, b) => a.dx.compareTo(b.dx));

      final extended = _extendUpperLid(
        upperOrdered: ordered,
        eyeOnLeftSideOfImage: eyeOnLeftSideOfImage,
        eyeBounds: eyeBounds,
        openness: openness,
      );

      final linerPath = DrawingUtils.catmullRomToBezierPath(extended, tension: 0.72);

      // width based on eye size
      final baseW = (eyeBounds.height * 0.085).clamp(1.2, 4.2).toDouble();

      // determine which end is INNER corner for taper
      final taperFromStart = !eyeOnLeftSideOfImage;

      // ✅ 1) Lash-bed tight shadow (adhesion)
      final lashBedShadow = Paint()
        ..color = Colors.black.withOpacity((0.14 * k).clamp(0.0, 0.30))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW * 1.05
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);

      // tiny downward offset to sit into lashes
      canvas.drawPath(linerPath.shift(const Offset(0, 0.6)), lashBedShadow);

      // ✅ 2) Soft blur base (keeps it skin-like)
      final blurPaint = Paint()
        ..color = Colors.black.withOpacity((0.16 * k).clamp(0.0, 0.32))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..strokeWidth = baseW * 2.10
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 9);

      canvas.drawPath(linerPath, blurPaint);

      // ✅ 3) Core line with INNER TAPER (alpha + width fade-in)
      const innerTaperFrac = 0.24;

      _drawVariableStroke(
        canvas: canvas,
        path: linerPath,
        baseWidth: baseW,
        baseAlpha: (0.62 * k).clamp(0.0, 0.90),
        innerTaperFrac: innerTaperFrac,
        taperFromStart: taperFromStart,
        segments: 46,
        paintFactory: (w, a) {
          return Paint()
            ..color = Colors.black.withOpacity(a)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true
            ..strokeWidth = w;
        },
      );

      // ---- Wing logic (keep stable) ----
      final allowByOpenness = openness > 0.16;
      final yaw = face.headEulerAngleY ?? 0.0;
      final roll = face.headEulerAngleZ ?? 0.0;
      final allowByPose = yaw.abs() < 18 && roll.abs() < 22;
      
      // Only draw wing if style supports it
      final styleAllowsWing = style == EyelinerStyle.subtle || style == EyelinerStyle.emoWing;
      
      if (!(allowByOpenness && allowByPose && styleAllowsWing)) return;

      final endIdx = eyeOnLeftSideOfImage ? 0 : (extended.length - 1);
      final prevIdx = eyeOnLeftSideOfImage
          ? min(2, extended.length - 1)
          : max(extended.length - 3, 0);

      final end = extended[endIdx];
      final prev = extended[prevIdx];

      final lidDir = ui.Offset(end.dx - prev.dx, end.dy - prev.dy);
      final outwardSign = eyeOnLeftSideOfImage ? -1.0 : 1.0;

      if (lidDir.dx.sign != outwardSign.sign) return;

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

      // ✅ 4️⃣ Add wing extension ONLY for Emo style (more dramatic)
      if (style == EyelinerStyle.emoWing) {
        // Make emo wing more dramatic
        final emoWingLen = wingLen * 1.5;
        final emoWingUp = wingUp * 1.3;
        
        final emoWingEnd = ui.Offset(
          end.dx + outwardSign * emoWingLen,
          end.dy - emoWingUp,
        );

        final emoWingPath = Path()
          ..moveTo(end.dx, end.dy)
          ..quadraticBezierTo(
            end.dx + outwardSign * (emoWingLen * 0.6),
            end.dy - (emoWingUp * 0.7),
            emoWingEnd.dx,
            emoWingEnd.dy,
          );

        final emoWingBlur = Paint()
          ..color = Colors.black.withOpacity((0.20 * k).clamp(0.0, 0.35))
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..strokeWidth = baseW * 2.2
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 11);

        canvas.drawPath(emoWingPath, emoWingBlur);

        final emoWingPaint = Paint()
          ..color = Colors.black.withOpacity((0.75 * k).clamp(0.0, 0.95))
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..strokeWidth = baseW * 1.2;

        canvas.drawPath(emoWingPath, emoWingPaint);
      } else {
        // Regular wing for subtle style
        final wingBlur = Paint()
          ..color = Colors.black.withOpacity((0.14 * k).clamp(0.0, 0.28))
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..strokeWidth = baseW * 1.9
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 9);

        canvas.drawPath(wingPath, wingBlur);

        final wingPaint = Paint()
          ..color = Colors.black.withOpacity((0.58 * k).clamp(0.0, 0.9))
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..strokeWidth = baseW * 0.95;

        canvas.drawPath(wingPath, wingPaint);
      }
    }

    drawEyeliner(FaceContourType.leftEye);
    drawEyeliner(FaceContourType.rightEye);
  }
}
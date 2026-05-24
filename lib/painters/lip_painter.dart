import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils.dart'; // ✅ single source of truth for LipFinish + DrawingUtils

class LipPainter {
  final Face face;
  final Color lipstickColor;
  final double intensity;
  final LipFinish lipFinish;

  LipPainter({
    required this.face,
    required this.lipstickColor,
    required this.intensity,
    this.lipFinish = LipFinish.glossy,
  });

  void paint(Canvas canvas, Size size) {
    final k = intensity.clamp(0.0, 1.0);
    if (k <= 0.001) return;

    final upper = face.contours[FaceContourType.upperLipTop]?.points;
    final lower = face.contours[FaceContourType.lowerLipBottom]?.points;

    if (upper == null ||
        lower == null ||
        upper.length < 6 ||
        lower.length < 6) {
      return;
    }

    final upperPts = upper
        .map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble()))
        .toList();

    final lowerPts = lower
        .map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble()))
        .toList();

    final lipPath = _buildLipRegionPath(upperPts, lowerPts);

    final bounds = lipPath.getBounds();
    final lipW = bounds.width;
    final lipH = bounds.height;

    if (lipW <= 1 || lipH <= 1) return;

    final center = bounds.center;

    final sigmaBase = max(lipW, lipH) * 0.025;
    final sigmaSoft = sigmaBase.clamp(1.2, 4.5);
    final sigmaFeather = (sigmaBase * 1.15).clamp(1.8, 6.0);

    final isMatte = lipFinish == LipFinish.matte;

    final darkness =
        (1.0 - ((lipstickColor.red + lipstickColor.green + lipstickColor.blue) / 765.0))
            .clamp(0.0, 1.0);

    final saturation =
        (([lipstickColor.red, lipstickColor.green, lipstickColor.blue].reduce(max) -
                    [lipstickColor.red, lipstickColor.green, lipstickColor.blue].reduce(min)) /
                255.0)
            .clamp(0.0, 1.0);

    final isDarkOrBold = darkness > 0.42 || saturation > 0.45;

    final pigment = isDarkOrBold
        ? 0.78
        : isMatte
            ? 0.66
            : 0.56;

    final depthOpacity = isDarkOrBold ? 0.28 : 0.12;
    final glossOpacity = isDarkOrBold ? 0.045 : 0.10;

    final layerBounds = bounds.inflate(max(8.0, max(lipW, lipH) * 0.25));

    canvas.saveLayer(layerBounds, Paint());

    final basePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        center,
        max(lipW, lipH) * 0.95,
        [
          lipstickColor.withOpacity(pigment * k),
          lipstickColor.withOpacity((pigment * 0.82) * k),
          lipstickColor.withOpacity((pigment * 0.45) * k),
        ],
        const [0.0, 0.70, 1.0],
      )
      ..blendMode = BlendMode.srcOver
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        sigmaSoft,
      );

    canvas.drawPath(lipPath, basePaint);

    final depthPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = lipstickColor.withOpacity(depthOpacity * k)
      ..blendMode = BlendMode.multiply
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        sigmaSoft * 0.75,
      );

    canvas.drawPath(lipPath, depthPaint);

    if (!isMatte && glossOpacity > 0) {
      final highlightCenter = ui.Offset(
        center.dx,
        center.dy - lipH * 0.18,
      );

      final highlightShader = ui.Gradient.radial(
        highlightCenter,
        max(lipW, lipH) * 0.42,
        [
          Colors.white.withOpacity(glossOpacity * k),
          Colors.white.withOpacity(0.0),
        ],
        const [0.0, 1.0],
      );

      canvas.drawPath(
        lipPath,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.fill
          ..shader = highlightShader
          ..blendMode = BlendMode.srcOver
          ..maskFilter = ui.MaskFilter.blur(
            ui.BlurStyle.normal,
            sigmaSoft * 0.65,
          ),
      );
    }

    canvas.drawPath(
      lipPath,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.6, lipW * 0.018)
        ..color = lipstickColor.withOpacity(0.18 * k)
        ..blendMode = BlendMode.multiply
        ..maskFilter = ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          sigmaFeather,
        ),
    );

    canvas.restore();
  }

  Path _buildLipRegionPath(List<ui.Offset> upper, List<ui.Offset> lower) {
    // Smooth upper & lower with Catmull-Rom from your utils
    final upperPath = DrawingUtils.catmullRomToBezierPath(upper, tension: 0.72);
    final lowerRev = lower.reversed.toList();
    final lowerPath = DrawingUtils.catmullRomToBezierPath(lowerRev, tension: 0.72);

    // Combine into closed region
    final p = Path();
    // Start at first upper point
    p.addPath(upperPath, ui.Offset.zero);
    // Connect to lower
    p.lineTo(lowerRev.first.dx, lowerRev.first.dy);
    p.addPath(lowerPath, ui.Offset.zero);
    p.close();
    return p;
  }
}
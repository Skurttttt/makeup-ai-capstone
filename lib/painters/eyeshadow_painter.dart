import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils.dart';

class EyeshadowPainter {
  final Face face;
  final Color eyeshadowColor;
  final double intensity;

  final Path? leftEyelinerPath;
  final Path? rightEyelinerPath;

  final bool debugMode;

  EyeshadowPainter({
    required this.face,
    required this.eyeshadowColor,
    required this.intensity,
    this.leftEyelinerPath,
    this.rightEyelinerPath,
    this.debugMode = false,
  });

  void paint(Canvas canvas, Size size) {
    if (intensity <= 0.001) return;

    _paintEye(
      canvas: canvas,
      eyeType: FaceContourType.leftEye,
      eyelinerPath: leftEyelinerPath,
    );

    _paintEye(
      canvas: canvas,
      eyeType: FaceContourType.rightEye,
      eyelinerPath: rightEyelinerPath,
    );
  }

  void _paintEye({
    required Canvas canvas,
    required FaceContourType eyeType,
    required Path? eyelinerPath,
  }) {
    if (eyelinerPath == null) return;

    final pts = face.contours[eyeType]?.points;
    if (pts == null || pts.length < 6) return;

    final eyeOffsets = pts
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList();

    final eyeBounds = DrawingUtils.boundsOf(eyeOffsets);

    final eyeW = eyeBounds.width;
    final eyeH = eyeBounds.height;

    // FIXED: Reduced height to prevent extending too close to brow
    final lidTop = eyeBounds.top - eyeH * 1.10;
    final lidBottom = eyeBounds.top + eyeH * 0.08;

    final lidPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            eyeBounds.left - eyeW * 0.14,
            lidTop,
            eyeBounds.right + eyeW * 0.14,
            lidBottom,
          ),
          Radius.circular(eyeH * 0.55),
        ),
      );

    final eyeHole = DrawingUtils.pathFromPoints(eyeOffsets);

    final safeLidRegion = Path.combine(
      PathOperation.difference,
      lidPath,
      eyeHole,
    );

    final safeRegionAboveEyeliner = Path.combine(
      PathOperation.difference,
      safeLidRegion,
      eyelinerPath,
    );

    // 1) SOFT BASE WASH
    final baseShader = ui.Gradient.linear(
      Offset(eyeBounds.center.dx, lidBottom),
      Offset(eyeBounds.center.dx, lidTop),
      [
        eyeshadowColor.withOpacity(0.26 * intensity),
        eyeshadowColor.withOpacity(0.16 * intensity),
        Colors.transparent,
      ],
      const [0.0, 0.55, 1.0],
    );

    final basePaint = Paint()
      ..shader = baseShader
      ..blendMode = BlendMode.srcOver
      ..isAntiAlias = true
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        (eyeH * 0.24).clamp(2.0, 6.0),
      );

    canvas.drawPath(safeRegionAboveEyeliner, basePaint);

    // 2) CREASE SHADING - Reduced strength
    final creaseY = eyeBounds.top - eyeH * 0.75;

    final creaseRect = Rect.fromCenter(
      center: Offset(eyeBounds.center.dx, creaseY),
      width: eyeW * 1.15,
      height: eyeH * 0.75,
    );

    final creasePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          creaseRect,
          Radius.circular(eyeH * 0.45),
        ),
      );

    final creaseRegion = Path.combine(
      PathOperation.intersect,
      safeRegionAboveEyeliner,
      creasePath,
    );

    final creasePaint = Paint()
      ..color = eyeshadowColor.withOpacity(0.10 * intensity) // Reduced from 0.18
      ..blendMode = BlendMode.multiply
      ..isAntiAlias = true
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        (eyeH * 0.20).clamp(1.8, 5.0),
      );

    canvas.drawPath(creaseRegion, creasePaint);

    // 3) OUTER CORNER DEPTH - Fixed position and reduced strength
    final isLeft = eyeType == FaceContourType.leftEye;
    final outerX = isLeft
        ? eyeBounds.left + eyeW * 0.08
        : eyeBounds.right - eyeW * 0.08;

    final outerShader = ui.Gradient.radial(
      Offset(
        outerX,
        eyeBounds.top - eyeH * 0.30,
      ),
      (eyeW * 0.58).clamp(14.0, 55.0),
      [
        eyeshadowColor.withOpacity(0.14 * intensity), // Reduced from 0.24
        eyeshadowColor.withOpacity(0.04 * intensity), // Reduced from 0.10
        Colors.transparent,
      ],
      const [0.0, 0.55, 1.0],
    );

    final outerPaint = Paint()
      ..shader = outerShader
      ..blendMode = BlendMode.multiply
      ..isAntiAlias = true
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        (eyeH * 0.24).clamp(2.0, 5.5), // Softened blur
      );

    canvas.drawPath(safeRegionAboveEyeliner, outerPaint);

    if (debugMode) {
      final dbg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.green.withOpacity(0.7);

      canvas.drawRect(eyeBounds, dbg);
      canvas.drawPath(safeRegionAboveEyeliner, dbg);
    }
  }
}
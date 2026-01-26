// lib/painters/eyeshadow_painter.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils.dart';

class EyeshadowPainter {
  final Face face;
  final Color eyeshadowColor;
  final double intensity;

  /// 👇 NEW (optional-safe)
  /// Pass the eyeliner path (upper lash/liner path) if available.
  final Path? eyelinerPath;

  EyeshadowPainter({
    required this.face,
    required this.eyeshadowColor,
    required this.intensity,
    this.eyelinerPath,
  });

  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    if (eyelinerPath == null) return;

    // NOTE: This version uses LEFT eye contour for bounds reference
    // (matches your snippet exactly).
    final eyePts = face.contours[FaceContourType.leftEye]?.points;
    if (eyePts == null || eyePts.length < 3) return;

    final eyeOffsets = eyePts
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList();

    final eyeBounds = DrawingUtils.boundsOf(eyeOffsets);
    final eyeH = eyeBounds.height;

    // 🔒 Upper expansion only (eyelid)
    final shadowRegion = Path.from(eyelinerPath!);

    shadowRegion.addRect(
      Rect.fromLTRB(
        eyeBounds.left,
        eyeBounds.top - eyeH * 1.2, // 👈 FULL eyelid height
        eyeBounds.right,
        eyeBounds.top + eyeH * 0.05,
      ),
    );

    // 🚫 Subtract eyeball
    final eyeHole = DrawingUtils.pathFromPoints(eyeOffsets);
    final finalRegion =
        Path.combine(PathOperation.difference, shadowRegion, eyeHole);

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(eyeBounds.center.dx, eyeBounds.top),
        Offset(eyeBounds.center.dx, eyeBounds.top - eyeH),
        [
          eyeshadowColor.withOpacity(0.45 * intensity),
          eyeshadowColor.withOpacity(0.15 * intensity),
          Colors.transparent,
        ],
        const [0.0, 0.6, 1.0],
      )
      ..blendMode = BlendMode.multiply
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1);

    // If you want blur to scale with the eye height (like your snippet),
    // use this instead of the line above:
    // ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, eyeH * 0.4);

    // But to match your snippet exactly, we'll set it properly:
    paint.maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, eyeH * 0.4);

    canvas.drawPath(finalRegion, paint);
  }
}

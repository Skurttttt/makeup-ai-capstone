// lib/makeup_overlay_painter.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'utils.dart'; // LipFinish
import 'look_engine.dart'; // FaceShape, EyelinerStyle

import 'lip_painter.dart';
import 'eyeshadow_painter.dart';
import 'eyeliner_painter.dart';
import 'blush_painter.dart';
import 'contour_highlight_painter.dart';
import 'eyebrow_painter.dart'; // ✅ NEW

class MakeupOverlayPainter extends CustomPainter {
  final ui.Image image;
  final Face face;
  final Color lipstickColor;
  final Color blushColor;
  final Color eyeshadowColor;
  final double intensity;
  final FaceShape faceShape;
  final EyelinerStyle eyelinerStyle; // ✅ A) Added field for eyeliner style
  final LipFinish lipFinish;

  /// sampled skin color (FaceProfile avgR/G/B)
  final Color? skinColor;

  /// ✅ scene luminance (0..1) from captured still image
  final double sceneLuminance;

  late final LipPainter _lipPainter;
  late final EyeshadowPainter _eyeshadowPainter;
  late final EyelinerPainter _eyelinerPainter; // ✅ A) Added field
  late final EyebrowPainter _eyebrowPainter; // ✅ NEW
  late final BlushPainter _blushPainter;
  late final ContourHighlightPainter _contourPainter;

  // ✅ B) Updated constructor with eyelinerStyle parameter
  MakeupOverlayPainter({
    required this.image,
    required this.face,
    required this.lipstickColor,
    required this.blushColor,
    required this.eyeshadowColor,
    required this.intensity,
    required this.faceShape,
    this.eyelinerStyle = EyelinerStyle.subtle, // ✅ B) Added with default
    this.lipFinish = LipFinish.glossy,
    this.skinColor,
    this.sceneLuminance = 0.50,
  }) {
    _lipPainter = LipPainter(
      face: face,
      lipstickColor: lipstickColor,
      intensity: intensity,
      lipFinish: lipFinish,
    );

    _eyeshadowPainter = EyeshadowPainter(
      face: face,
      eyeshadowColor: eyeshadowColor,
      intensity: intensity,
    );

    // ✅ C) Updated EyelinerPainter initialization
    _eyelinerPainter = EyelinerPainter(
      face: face,
      intensity: intensity,
      style: eyelinerStyle, // ✅ C) Pass the style parameter
    );

    // ✅ NEW: Eyebrows (painter-only, no look engine dependency)
    // You can tweak browColor/thickness/hairStrokes anytime.
    _eyebrowPainter = EyebrowPainter(
      face: face,
      browColor: const Color(0xFF2B1B14), // natural dark brown (change if you want)
      intensity: intensity,
      thickness: 1.05, // 0.9 natural, 1.2 medium, 1.5 bold
      hairStrokes: true, // set false for a powder-brow look
      sceneLuminance: sceneLuminance,
      debugMode: false,
    );

    _blushPainter = BlushPainter(
      face: face,
      blushColor: blushColor,
      intensity: intensity,
      faceShape: faceShape,
      skinColor: skinColor,
      sceneLuminance: sceneLuminance,
      faceId: face.trackingId ?? -1,
    );

    _contourPainter = ContourHighlightPainter(
      face: face,
      intensity: intensity,
      faceShape: faceShape,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());

    final k = intensity.clamp(0.0, 1.0);
    if (k <= 0.0) return;

    // ✅ Suggested order (brows first so liner/shadow sit nicely)
    _eyebrowPainter.paint(canvas, size);

    _eyeshadowPainter.paint(canvas, size);
    _eyelinerPainter.paint(canvas, size);

    _blushPainter.paint(canvas, size);
    _contourPainter.paint(canvas, size);

    // Lips last (so they stay clean on top)
    _lipPainter.paint(canvas, size);
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
        oldDelegate.eyelinerStyle != eyelinerStyle || // ✅ Added eyelinerStyle check
        oldDelegate.lipFinish != lipFinish ||
        oldDelegate.skinColor != skinColor ||
        oldDelegate.sceneLuminance != sceneLuminance;
  }
}
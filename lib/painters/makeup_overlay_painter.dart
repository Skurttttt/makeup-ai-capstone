// lib/painters/makeup_overlay_painter.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils.dart';
import '../look_engine.dart';

import 'lip_painter.dart';
import 'eyeshadow_painter.dart';
import 'eyeliner_painter.dart';
import 'blush_painter.dart';
import 'contour_highlight_painter.dart';
import 'eyebrow_painter.dart';

class MakeupOverlayPainter extends CustomPainter {
  final ui.Image image;
  final Face face;

  final Color lipstickColor;
  final Color blushColor;
  final Color eyeshadowColor;

  final double intensity;
  final FaceShape faceShape;
  final EyelinerStyle eyelinerStyle;
  final LipFinish lipFinish;

  final Color? skinColor;
  final double sceneLuminance;

  // ✅ NEW
  final MakeupLookPreset preset;
  final bool debugMode;
  final bool isLiveMode;
  final double? leftCheekLuminance;
  final double? rightCheekLuminance;

  late final LipPainter _lipPainter;
  late final EyeshadowPainter _eyeshadowPainter;
  late final EyelinerPainter _eyelinerPainter;
  late final EyebrowPainter _eyebrowPainter;
  late final BlushPainter _blushPainter;
  late final ContourHighlightPainter _contourPainter;

  MakeupOverlayPainter({
    required this.image,
    required this.face,
    required this.lipstickColor,
    required this.blushColor,
    required this.eyeshadowColor,
    required this.intensity,
    required this.faceShape,
    required this.preset, // ✅ REQUIRED

    this.eyelinerStyle = EyelinerStyle.subtle,
    this.lipFinish = LipFinish.glossy,
    this.skinColor,
    this.sceneLuminance = 0.5,

    // ✅ NEW
    this.debugMode = false,
    this.isLiveMode = false,
    this.leftCheekLuminance,
    this.rightCheekLuminance,
  }) {
    debugPrint('🎨 MakeupOverlayPainter created');
    debugPrint('🎨 Eyeshadow color: $eyeshadowColor');
    debugPrint('🎨 Intensity: $intensity');
    debugPrint('🎨 Face tracking ID: ${face.trackingId}');
    debugPrint('🎨 FaceShape: $faceShape');
    debugPrint('🎨 EyelinerStyle: $eyelinerStyle');
    debugPrint('🎨 LipFinish: $lipFinish');
    debugPrint('🎨 Lipstick color: $lipstickColor');
    debugPrint('🎨 Blush color: $blushColor');
    debugPrint('🎨 Scene luminance: $sceneLuminance');
    debugPrint('🎨 Preset: $preset');
    debugPrint('🎨 Debug mode: $debugMode');
    debugPrint('🎨 Is live mode: $isLiveMode');
    if (leftCheekLuminance != null && rightCheekLuminance != null) {
      debugPrint('🎨 Cheek luminance: L=$leftCheekLuminance, R=$rightCheekLuminance');
    }

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

    _eyelinerPainter = EyelinerPainter(
      face: face,
      intensity: intensity,
      style: eyelinerStyle,
    );

    _eyebrowPainter = EyebrowPainter(
      face: face,
      browColor: const Color(0xFF2B1B14),
      intensity: intensity,
      thickness: 1.05,
      hairStrokes: true,
      sceneLuminance: sceneLuminance,
      debugMode: debugMode,
    );

    _blushPainter = BlushPainter(
      face: face,
      blushColor: blushColor,
      intensity: intensity,
      faceShape: faceShape,
      skinColor: skinColor,
      sceneLuminance: sceneLuminance,
      faceId: face.trackingId ?? -1,

      // ✅ required
      isLiveMode: true,

      // ✅ required
      lookStyle: 'natural', // or 'glam', 'emo', 'soft', 'bold'

      debugMode: false,
    );
    
    _contourPainter = ContourHighlightPainter(
      face: face,
      intensity: intensity,
      faceShape: faceShape,
    );

    debugPrint('✅ All painters initialized');
  }

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint('🎨 MakeupOverlayPainter.paint() called, size: $size');
    
    // Draw the base image
    canvas.drawImage(image, Offset.zero, Paint());
    
    // Draw a green debug square if in debug mode
    if (debugMode) {
      canvas.drawRect(
        Rect.fromLTWH(20, 20, 60, 60),
        Paint()
          ..color = Colors.green.withOpacity(0.8)
          ..style = PaintingStyle.fill,
      );
      debugPrint('🟢 GREEN SQUARE drawn at (20,20) size 60x60');
    }

    if (intensity <= 0) {
      debugPrint('⚠️ Skipping makeup - intensity is 0');
      return;
    }

    final effectiveIntensity = intensity.clamp(0.0, 1.0);
    debugPrint('🎨 Effective intensity: $effectiveIntensity');

    // Paint in correct order (back to front)
    debugPrint('🎨 Drawing eyebrows...');
    _eyebrowPainter.paint(canvas, size);
    
    debugPrint('🎨 Drawing eyeshadow...');
    _eyeshadowPainter.paint(canvas, size);
    
    debugPrint('🎨 Drawing eyeliner...');
    _eyelinerPainter.paint(canvas, size);
    
    debugPrint('🎨 Drawing blush...');
    _blushPainter.paint(canvas, size);
    
    debugPrint('🎨 Drawing contour/highlight...');
    _contourPainter.paint(canvas, size);
    
    debugPrint('🎨 Drawing lips...');
    _lipPainter.paint(canvas, size);
    
    debugPrint('✅ All makeup drawn');
  }

  @override
  bool shouldRepaint(covariant MakeupOverlayPainter old) {
    final shouldRepaint = 
        old.image != image ||
        old.face != face ||
        old.intensity != intensity ||
        old.faceShape != faceShape ||
        old.eyelinerStyle != eyelinerStyle ||
        old.preset != preset ||
        old.debugMode != debugMode ||
        old.isLiveMode != isLiveMode ||
        old.leftCheekLuminance != leftCheekLuminance ||
        old.rightCheekLuminance != rightCheekLuminance ||
        old.sceneLuminance != sceneLuminance;
    
    debugPrint('🎨 shouldRepaint: $shouldRepaint');
    return shouldRepaint;
  }
}
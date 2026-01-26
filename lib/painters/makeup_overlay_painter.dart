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

  // Track eyeliner path for eyeshadow integration
  Path? _eyelinerPath;

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
    debugPrint('✅ MakeupOverlayPainter initialized');
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

    // ✅ KEY INTEGRATION: Create painters in correct order
    
    // 1️⃣ Create and paint eyeliner FIRST (to get the path)
    debugPrint('🎨 Creating eyeliner painter...');
    final eyelinerPainter = EyelinerPainter(
      face: face,
      intensity: effectiveIntensity,
      style: eyelinerStyle,
    );
    
    debugPrint('🎨 Drawing eyeliner...');
    eyelinerPainter.paint(canvas, size);
    
    // Store the eyeliner path for eyeshadow
    _eyelinerPath = eyelinerPainter.lastEyelinerPath;
    debugPrint('🎨 Eyeliner path captured: ${_eyelinerPath != null}');

    // 2️⃣ Create eyeshadow painter USING eyeliner path as lower boundary
    debugPrint('🎨 Creating eyeshadow painter with eyeliner path...');
    final eyeshadowPainter = EyeshadowPainter(
      face: face,
      eyeshadowColor: eyeshadowColor,
      intensity: effectiveIntensity,
      eyelinerPath: _eyelinerPath, // 👈 KEY LINE
    );

    // 3️⃣ Create other painters
    debugPrint('🎨 Creating eyebrow painter...');
    final eyebrowPainter = EyebrowPainter(
      face: face,
      browColor: const Color(0xFF2B1B14),
      intensity: effectiveIntensity,
      thickness: 1.05,
      hairStrokes: true,
      sceneLuminance: sceneLuminance,
      debugMode: debugMode,
    );

    debugPrint('🎨 Creating blush painter...');
    final blushPainter = BlushPainter(
      face: face,
      blushColor: blushColor,
      intensity: effectiveIntensity,
      faceShape: faceShape,
      skinColor: skinColor,
      sceneLuminance: sceneLuminance,
      faceId: face.trackingId ?? -1,
      isLiveMode: true,
      lookStyle: 'natural', // or 'glam', 'emo', 'soft', 'bold'
      debugMode: false,
    );
    
    debugPrint('🎨 Creating contour/highlight painter...');
    final contourPainter = ContourHighlightPainter(
      face: face,
      intensity: effectiveIntensity,
      faceShape: faceShape,
    );

    debugPrint('🎨 Creating lip painter...');
    final lipPainter = LipPainter(
      face: face,
      lipstickColor: lipstickColor,
      intensity: effectiveIntensity,
      lipFinish: lipFinish,
    );

    // Paint in correct order (back to front)
    debugPrint('🎨 Drawing makeup layers...');
    
    // Background layers first
    debugPrint('🎨 1. Drawing eyebrows...');
    eyebrowPainter.paint(canvas, size);
    
    // ✅ Eyeshadow uses eyeliner path as lower boundary
    if (_eyelinerPath != null) {
      debugPrint('🎨 2. Drawing eyeshadow with eyeliner boundary...');
      eyeshadowPainter.paint(canvas, size);
    } else {
      debugPrint('⚠️ Skipping eyeshadow - no eyeliner path available');
    }
    
    // Foreground layers
    debugPrint('🎨 3. Drawing blush...');
    blushPainter.paint(canvas, size);
    
    debugPrint('🎨 4. Drawing contour/highlight...');
    contourPainter.paint(canvas, size);
    
    debugPrint('🎨 5. Drawing lips...');
    lipPainter.paint(canvas, size);
    
    // Note: Eyeliner was already painted first
    
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
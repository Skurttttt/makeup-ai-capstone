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

    // ✅ 1️⃣ Create eyeliner painter and build paths first (NO DRAW YET)
    debugPrint('🎨 Creating eyeliner painter...');
    final eyelinerPainter = EyelinerPainter(
      face: face,
      intensity: effectiveIntensity,
      style: eyelinerStyle,
    );

    // ✅ IMPORTANT: Build paths first (NO DRAW YET)
    debugPrint('🎨 Building eyeliner paths...');
    final paths = eyelinerPainter.buildPaths();
    debugPrint('🎨 Eyeliner paths built: left=${paths.left != null}, right=${paths.right != null}');

    // ✅ 2️⃣ Create eyeshadow painter with BOTH eye paths
    debugPrint('🎨 Creating eyeshadow painter with eyeliner paths...');
    final eyeshadowPainter = EyeshadowPainter(
      face: face,
      eyeshadowColor: eyeshadowColor,
      intensity: effectiveIntensity,
      leftEyelinerPath: paths.left,
      rightEyelinerPath: paths.right,
      // debug parameter might not exist in EyeshadowPainter - removed
    );

    // ✅ 3️⃣ Create other painters
    debugPrint('🎨 Creating eyebrow painter...');
    // In lib/painters/makeup_overlay_painter.dart, update the eyebrow painter instantiation:

    // ✅ 3️⃣ Create other painters
    debugPrint('🎨 Creating eyebrow painter...');
    final eyebrowPainter = EyebrowPainter(
      face: face,
      browColor: const Color(0xFF2B1B14),
      intensity: effectiveIntensity,
      thickness: 1.05,
      
      // ✅ Compatibility param (kept so your call compiles; ignored for now)
      hairStrokes: true,
      
      sceneLuminance: sceneLuminance,
      debugMode: debugMode,
      
      // ✅ NEW: Control debug point visibility
      debugShowPoints: false, // ✅ OFF = no dots, cleaner debug
      
      // ✅ Debug brow color (dark brown for realistic debug look)
      debugBrowColor: const Color(0xFF1A0E0A), // super dark brown
      debugBrowOpacity: 0.55,
      
      // ✅ IMPORTANT: set this correctly based on your camera preview pipeline
      // If you mirror the preview (common for front camera), set true.
      // If your ML input is already mirrored-corrected, set false.
      isMirrored: isLiveMode, // <-- best guess if live/front cam; adjust if needed
      
      // Optional stability tuning (safe defaults)
      emaAlpha: 0.84,
      holdLastGood: const Duration(milliseconds: 250),
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
      isLiveMode: isLiveMode,
      lookStyle: 'natural', // or 'glam', 'emo', 'soft', 'bold'
      debugMode: debugMode,
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

    // ✅ Paint in correct order for realism:
    debugPrint('🎨 Drawing makeup layers...');
    
    // 1) Brows (behind)
    debugPrint('🎨 1. Drawing eyebrows (behind)...');
    eyebrowPainter.paint(canvas, size);

    // 2) Eyeshadow (BEHIND eyeliner, using eyeliner paths as boundaries)
    debugPrint('🎨 2. Drawing eyeshadow (behind eyeliner)...');
    eyeshadowPainter.paint(canvas, size);

    // 3) Eyeliner (TOP layer, crisp - doesn't get washed out)
    debugPrint('🎨 3. Drawing eyeliner (top layer)...');
    eyelinerPainter.paint(canvas, size);

    // 4) Blush, contour, lips (foreground)
    debugPrint('🎨 4. Drawing blush...');
    blushPainter.paint(canvas, size);
    
    debugPrint('🎨 5. Drawing contour/highlight...');
    contourPainter.paint(canvas, size);
    
    debugPrint('🎨 6. Drawing lips...');
    lipPainter.paint(canvas, size);
    
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
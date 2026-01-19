import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_application_1/skin_analyzer.dart';

enum FaceShape { oval, round, square, heart, unknown }

// 1A) Added EyelinerStyle enum
enum EyelinerStyle {
  none,
  thin,       // thin eyeliner no wing
  subtle,     // subtle liner
  emoWing,    // heavier emo wing
}

// 1) Update the preset enum
enum MakeupLookPreset {
  noMakeup,
  everydayFresh,
  officeProfessional,
  cleanGirl,
  emo,
  debugPainterTest, // 🔧 TEMPORARY - Added debug preset
}

// 2) Update the label extension
extension MakeupLookPresetLabel on MakeupLookPreset {
  String get label {
    switch (this) {
      case MakeupLookPreset.noMakeup:
        return 'No-Makeup Look';
      case MakeupLookPreset.everydayFresh:
        return 'Everyday Fresh';
      case MakeupLookPreset.officeProfessional:
        return 'Office / Professional Look';
      case MakeupLookPreset.cleanGirl:
        return 'Clean Girl Look';
      case MakeupLookPreset.emo:
        return 'Emo Look';
      case MakeupLookPreset.debugPainterTest:
        return '🔧 Debug Painter Test';
    }
  }
}

/// ✅ Painter-friendly config
class MakeupLookConfig {
  final Color lipColor;
  final Color blushColor;
  final Color eyeshadowColor;
  
  // ✅ NEW: Eyeliner style
  final EyelinerStyle eyelinerStyle;

  /// global intensity multiplier (0..1)
  final double intensity;

  /// finish intent (your app currently supports matte / glossy)
  final bool glossyLips;

  const MakeupLookConfig({
    required this.lipColor,
    required this.blushColor,
    required this.eyeshadowColor,
    required this.eyelinerStyle,
    required this.intensity,
    required this.glossyLips,
  });
}

/// ✅ Your existing analysis model (kept for InstructionsPage)
class FaceProfile {
  final SkinTone skinTone;
  final Undertone undertone;
  final FaceShape faceShape;

  final int avgR;
  final int avgG;
  final int avgB;

  final double skinConfidence;
  final double undertoneConfidence;

  const FaceProfile({
    required this.skinTone,
    required this.undertone,
    required this.faceShape,
    required this.avgR,
    required this.avgG,
    required this.avgB,
    required this.skinConfidence,
    required this.undertoneConfidence,
  });

  factory FaceProfile.fromAnalysis(Face face, SkinAnalysisResult skin) {
    final shape = _detectFaceShape(face);
    return FaceProfile(
      skinTone: skin.tone,
      undertone: skin.undertone,
      faceShape: shape,
      avgR: skin.avgR,
      avgG: skin.avgG,
      avgB: skin.avgB,
      skinConfidence: skin.confidence,
      undertoneConfidence: _calculateUndertoneConfidence(skin),
    );
  }

  static double _calculateUndertoneConfidence(SkinAnalysisResult a) {
    // Simple heuristic: if confidence is high, undertone confidence follows
    // You can improve this later based on channel ratios and lighting.
    return (a.confidence).clamp(0.0, 1.0);
  }

  static FaceShape _detectFaceShape(Face face) {
    // ✅ SAFE heuristic (no non-existent jawLeft/chin landmarks)
    final box = face.boundingBox;
    final w = box.width;
    final h = box.height;

    if (w <= 0 || h <= 0) return FaceShape.unknown;

    final ratio = w / h;
    if (ratio > 0.95) return FaceShape.round;
    if (ratio < 0.75) return FaceShape.oval;
    return FaceShape.square;
  }
}

/// ✅ Instructions page model (kept untouched)
class LookResult {
  final String lookName;
  final Color lipstickColor;
  final Color blushColor;
  final Color eyeshadowColor;
  final List<String> steps;

  const LookResult({
    required this.lookName,
    required this.lipstickColor,
    required this.blushColor,
    required this.eyeshadowColor,
    required this.steps,
  });
}

class LookEngine {
  /// ✅ Use this for painters if you later want to switch the painter to config
  static MakeupLookConfig configFromPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.noMakeup:
        return const MakeupLookConfig(
          lipColor: Color(0xCCD89A9A),
          blushColor: Color(0x66F3C1C1),
          eyeshadowColor: Color(0x22EADAD3),
          eyelinerStyle: EyelinerStyle.none,
          intensity: 0.35,
          glossyLips: false,
        );

      case MakeupLookPreset.everydayFresh:
        return const MakeupLookConfig(
          lipColor: Color(0xCCC97878),
          blushColor: Color(0x66F0B08A),
          eyeshadowColor: Color(0x22E6CFC0),
          eyelinerStyle: EyelinerStyle.thin,
          intensity: 0.50,
          glossyLips: false,
        );

      case MakeupLookPreset.officeProfessional:
        return const MakeupLookConfig(
          lipColor: Color(0xCCB46A6A),
          blushColor: Color(0x66E3A4A4),
          eyeshadowColor: Color(0x22D9C4B6),
          eyelinerStyle: EyelinerStyle.subtle,
          intensity: 0.55,
          glossyLips: false,
        );

      case MakeupLookPreset.cleanGirl:
        return const MakeupLookConfig(
          lipColor: Color(0xCCD68080),
          blushColor: Color(0x66EFB2A4),
          eyeshadowColor: Color(0x22E7D8D1),
          eyelinerStyle: EyelinerStyle.thin,
          intensity: 0.50,
          glossyLips: true,
        );

      case MakeupLookPreset.emo:
        return const MakeupLookConfig(
          // Dark berry / plum lips (not pure black to avoid looking "painted")
          lipColor: Color(0xFF4A1F2D),
          // Minimal blush (kept low)
          blushColor: Color(0x331A0B10),
          // Smoky eyes (deep charcoal)
          eyeshadowColor: Color(0xFF1B1B1F),
          eyelinerStyle: EyelinerStyle.emoWing,
          // Stronger intensity for eyes
          intensity: 0.85,
          glossyLips: false,
        );

      // B) Add the Debug preset config
      case MakeupLookPreset.debugPainterTest:
        return const MakeupLookConfig(
          // Bright, highly visible colors for testing
          lipColor: Color(0xFFFF0000), // Bright red
          blushColor: Color(0xFFFF00FF), // Bright magenta
          eyeshadowColor: Color(0xFF0000FF), // Bright blue
          eyelinerStyle: EyelinerStyle.emoWing, // dramatic for testing
          intensity: 1.0, // Maximum intensity
          glossyLips: true,
        );
    }
  }

  /// ✅ Use this for InstructionsPage (user-picked look; profile only for placement notes)
  static LookResult fromPreset(MakeupLookPreset preset, {FaceProfile? profile}) {
    final placement = _blushPlacement(profile?.faceShape ?? FaceShape.unknown);

    switch (preset) {
      case MakeupLookPreset.noMakeup:
        return LookResult(
          lookName: 'No-Makeup Look',
          lipstickColor: const Color(0xCCD89A9A),
          blushColor: const Color(0x66F3C1C1),
          eyeshadowColor: const Color(0x22EADAD3),
          steps: [
            'Very light blush only.',
            placement,
            'Soft brows.',
            'No liner wing.',
            'Lip tint only.',
          ],
        );

      case MakeupLookPreset.everydayFresh:
        return LookResult(
          lookName: 'Everyday Fresh',
          lipstickColor: const Color(0xCCC97878),
          blushColor: const Color(0x66F0B08A),
          eyeshadowColor: const Color(0x22E6CFC0),
          steps: [
            'Soft peach blush.',
            placement,
            'Thin eyeliner (no wing).',
            'Natural brows.',
            'MLBB lips.',
          ],
        );

      case MakeupLookPreset.officeProfessional:
        return LookResult(
          lookName: 'Office / Professional Look',
          lipstickColor: const Color(0xCCB46A6A),
          blushColor: const Color(0x66E3A4A4),
          eyeshadowColor: const Color(0x22D9C4B6),
          steps: [
            'Defined brows.',
            'Subtle liner.',
            'Muted blush.',
            placement,
            'Muted satin-like lips (finish later).',
          ],
        );

      case MakeupLookPreset.cleanGirl:
        return LookResult(
          lookName: 'Clean Girl Look',
          lipstickColor: const Color(0xCCD68080),
          blushColor: const Color(0x66EFB2A4),
          eyeshadowColor: const Color(0x22E7D8D1),
          steps: [
            'Brushed-up brows.',
            'Skin-like blush.',
            placement,
            'Minimal eye definition.',
            'Glossy lips (finish later).',
          ],
        );

      case MakeupLookPreset.emo:
        return LookResult(
          lookName: 'Emo Look',
          lipstickColor: const Color(0xFF4A1F2D),
          blushColor: const Color(0x331A0B10),
          eyeshadowColor: const Color(0xFF1B1B1F),
          steps: [
            'Smoky eyes: blend charcoal from lash line upward.',
            'Add darker depth on outer corner for a heavier emo vibe.',
            'Optional: lower lash line smoke for stronger intensity.',
            'Brows: slightly straighter, soft but defined.',
            'Lips: deep berry/plum for a wearable emo finish.',
            'Blush: minimal (keep cheeks neutral).',
          ],
        );

      // Add Debug preset for instructions page too
      case MakeupLookPreset.debugPainterTest:
        return LookResult(
          lookName: '🔧 Debug Painter Test',
          lipstickColor: const Color(0xFFFF0000),
          blushColor: const Color(0xFFFF00FF),
          eyeshadowColor: const Color(0xFF0000FF),
          steps: [
            'This is a DEBUG mode to test all painters.',
            'All makeup elements should be visible:',
            '- Bright red lips',
            '- Bright magenta blush',
            '- Bright blue eyeshadow',
            '- Dramatic emo-wing eyeliner',
            '- Eyebrows (if implemented)',
            '- Contour/highlight (if implemented)',
            'Use this to verify all painters are working.',
          ],
        );
    }
  }

  static String _blushPlacement(FaceShape faceShape) {
    switch (faceShape) {
      case FaceShape.round:
        return 'Blush placement: slightly higher and outward to lift.';
      case FaceShape.square:
        return 'Blush placement: soften corners by blending diagonally up.';
      case FaceShape.heart:
        return 'Blush placement: focus on outer cheeks, keep center soft.';
      case FaceShape.oval:
        return 'Blush placement: classic apples → blend up.';
      case FaceShape.unknown:
        return 'Blush placement: apply on apples and blend upward softly.';
    }
  }

  /// ✅ Helper function to get eyeliner style from preset
  static EyelinerStyle eyelinerStyleFromPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.noMakeup:
        return EyelinerStyle.none;
      case MakeupLookPreset.everydayFresh:
        return EyelinerStyle.thin;
      case MakeupLookPreset.officeProfessional:
        return EyelinerStyle.subtle;
      case MakeupLookPreset.cleanGirl:
        return EyelinerStyle.thin;
      case MakeupLookPreset.emo:
        return EyelinerStyle.emoWing;
      case MakeupLookPreset.debugPainterTest:
        return EyelinerStyle.emoWing; // Use dramatic eyeliner for debugging
    }
  }
}
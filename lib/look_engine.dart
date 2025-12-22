import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'skin_analyzer.dart';

enum FaceShape { oval, round, square, heart, unknown }

class FaceProfile {
  final SkinTone skinTone;
  final Undertone undertone;
  final FaceShape faceShape;

  /// Helpful for debugging
  final int avgR;
  final int avgG;
  final int avgB;
  final double skinConfidence;

  const FaceProfile({
    required this.skinTone,
    required this.undertone,
    required this.faceShape,
    required this.avgR,
    required this.avgG,
    required this.avgB,
    required this.skinConfidence,
  });

  static FaceShape classifyFaceShape(Face face) {
    final box = face.boundingBox;
    final ratio = box.height / max(1.0, box.width);

    if (ratio >= 1.35) return FaceShape.oval;
    if (ratio >= 1.18) return FaceShape.round;
    return FaceShape.square;
  }

  static FaceProfile fromAnalysis(Face face, SkinAnalysisResult a) {
    final shape = classifyFaceShape(face);

    // Optional: very rough heart detection if forehead/jaw differs
    // (you can upgrade this later using contours)
    FaceShape refined = shape;
    if (shape == FaceShape.oval) {
      refined = FaceShape.oval;
    }

    return FaceProfile(
      skinTone: a.tone,
      undertone: a.undertone,
      faceShape: refined,
      avgR: a.avgR,
      avgG: a.avgG,
      avgB: a.avgB,
      skinConfidence: a.confidence,
    );
  }
}

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
  static LookResult recommendLook(FaceProfile p) {
    final lipstick = _lipstickFor(p.undertone, p.skinTone);
    final blush = _blushFor(p.undertone, p.skinTone);
    final eyeshadow = _eyeshadowFor(p.undertone);

    final lookName = switch (p.undertone) {
      Undertone.warm => 'Warm Soft Glam',
      Undertone.cool => 'Cool Rosy Glam',
      Undertone.neutral => 'Neutral Everyday',
    };

    final steps = <String>[
      'Prep: Cleanse + moisturize, then apply sunscreen.',
      'Base: Choose a foundation shade for ${p.skinTone.name} skin tone (blend to neck).',
      'Brows: Lightly define your brows; keep it natural.',
      'Eyes: Apply a soft ${p.undertone.name} eyeshadow shade and blend outward.',
      _blushPlacement(p.faceShape),
      'Lips: Apply a ${p.undertone.name}-friendly lipstick and tap-blend the edges.',
      'Finish: Set with powder/spray for longer wear.',
      if (p.skinConfidence < 0.35)
        'Tip: Lighting may affect skin detection. Try scanning near a window or white light.',
    ];

    return LookResult(
      lookName: lookName,
      lipstickColor: lipstick,
      blushColor: blush,
      eyeshadowColor: eyeshadow,
      steps: steps,
    );
  }

  static String _blushPlacement(FaceShape shape) {
    return switch (shape) {
      FaceShape.oval =>
        'Blush: Sweep blush on the apples of your cheeks and blend slightly upward.',
      FaceShape.round =>
        'Blush: Place blush slightly above the apples and blend upward to lift the face.',
      FaceShape.square =>
        'Blush: Focus blush on the apples to soften the jawline.',
      FaceShape.heart =>
        'Blush: Apply in a “C” shape from cheekbones toward temples for balance.',
      FaceShape.unknown =>
        'Blush: Apply on the apples and blend upward softly.',
    };
  }

  static Color _lipstickFor(Undertone u, SkinTone t) {
    return switch (u) {
      Undertone.warm => switch (t) {
          SkinTone.light => const Color(0xCCB55A6A),
          SkinTone.medium => const Color(0xCCB83A5A),
          SkinTone.tan => const Color(0xCC9F2F45),
          SkinTone.deep => const Color(0xCC7D1F33),
        },
      Undertone.cool => switch (t) {
          SkinTone.light => const Color(0xCCB24D6A),
          SkinTone.medium => const Color(0xCC9E2E5C),
          SkinTone.tan => const Color(0xCC7D1F52),
          SkinTone.deep => const Color(0xCC5A123B),
        },
      Undertone.neutral => switch (t) {
          SkinTone.light => const Color(0xCCB8736A),
          SkinTone.medium => const Color(0xCC9C4B5A),
          SkinTone.tan => const Color(0xCC7B3342),
          SkinTone.deep => const Color(0xCC5B1E2D),
        },
    };
  }

  static Color _blushFor(Undertone u, SkinTone t) {
    return switch (u) {
      Undertone.warm => switch (t) {
          SkinTone.light => const Color(0x66F3A7A7),
          SkinTone.medium => const Color(0x66F08A8A),
          SkinTone.tan => const Color(0x66E86A6A),
          SkinTone.deep => const Color(0x669D3A3A),
        },
      Undertone.cool => switch (t) {
          SkinTone.light => const Color(0x668EB3FF),
          SkinTone.medium => const Color(0x66809AF2),
          SkinTone.tan => const Color(0x666A7FD1),
          SkinTone.deep => const Color(0x664D5B9F),
        },
      Undertone.neutral => switch (t) {
          SkinTone.light => const Color(0x66F2B6A0),
          SkinTone.medium => const Color(0x66EFA08A),
          SkinTone.tan => const Color(0x66D97A64),
          SkinTone.deep => const Color(0x66914B3B),
        },
    };
  }

  static Color _eyeshadowFor(Undertone u) {
    return switch (u) {
      Undertone.warm => const Color(0x443A2A1F),
      Undertone.cool => const Color(0x44423A59),
      Undertone.neutral => const Color(0x44323232),
    };
  }
}

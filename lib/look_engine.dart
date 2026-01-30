// lib/look_engine.dart
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'skin_analyzer.dart';

enum FaceShape { oval, round, square, heart, unknown }

// 1A) EyelinerStyle enum (kept)
enum EyelinerStyle {
  none,
  thin, // thin eyeliner no wing
  subtle, // subtle liner
  emoWing, // heavier emo wing
}

// ✅ Presets: required 5 looks + debugPainterTest (keep)
enum MakeupLookPreset {
  emo,
  softGlam,
  dollKBeauty,
  bronzedGoddess,
  boldEditorial,

  debugPainterTest, // 🔧 MUST remain
}

// ✅ Clean labels (kept)
extension MakeupLookPresetLabel on MakeupLookPreset {
  String get label {
    switch (this) {
      case MakeupLookPreset.emo:
        return 'Emo';
      case MakeupLookPreset.softGlam:
        return 'Soft Glam';
      case MakeupLookPreset.dollKBeauty:
        return 'Doll / K-Beauty';
      case MakeupLookPreset.bronzedGoddess:
        return 'Bronzed Goddess';
      case MakeupLookPreset.boldEditorial:
        return 'Bold Editorial';
      case MakeupLookPreset.debugPainterTest:
        return '🔧 Debug Painter Test';
    }
  }
}

/// ✅ Painter-friendly config (public API kept)
class MakeupLookConfig {
  final Color lipColor;
  final Color blushColor;
  final Color eyeshadowColor;

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

/// ✅ Your existing analysis model (kept)
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
    return (a.confidence).clamp(0.0, 1.0);
  }

  static FaceShape _detectFaceShape(Face face) {
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

/// ✅ Instructions page model (kept)
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
  // ---------------------------
  // PALETTE SYSTEM (IN-FILE)
  // ---------------------------

  static const double _minUndertoneConfidence = 0.55;
  static const double _minSkinConfidence = 0.55;

  static bool _lowSkinConfidence(FaceProfile? p) {
    if (p == null) return false;
    return p.skinConfidence < _minSkinConfidence;
  }

  /// Undertone selection rule:
  /// - If undertoneConfidence is low -> force neutral
  /// - Else warm/cool/neutral
  static Undertone _undertoneKey(FaceProfile? p) {
    if (p == null) return Undertone.neutral;
    if (p.undertoneConfidence < _minUndertoneConfidence) return Undertone.neutral;
    if (p.undertone == Undertone.warm) return Undertone.warm;
    if (p.undertone == Undertone.cool) return Undertone.cool;
    return Undertone.neutral;
  }

  /// Each look: warm/cool/neutral variants including browColor
  static final Map<MakeupLookPreset, _LookPalette> _palettes = {
    // 1) Emo
    MakeupLookPreset.emo: _LookPalette(
      baseIntensity: 0.88,
      glossy: false,
      eyeliner: EyelinerStyle.emoWing,
      warm: const _LookVariant(
        lipColor: Color(0xFF5A1E2A),
        blushColor: Color(0x331A0B10), // minimal
        eyeshadowColor: Color(0xFF1B1B1F), // charcoal
        browColor: Color(0xFF3A2A24),
      ),
      cool: const _LookVariant(
        lipColor: Color(0xFF3F1830),
        blushColor: Color(0x331A0B10),
        eyeshadowColor: Color(0xFF1B1B1F),
        browColor: Color(0xFF2B2530),
      ),
      neutral: const _LookVariant(
        lipColor: Color(0xFF4A1F2D),
        blushColor: Color(0x331A0B10),
        eyeshadowColor: Color(0xFF1B1B1F),
        browColor: Color(0xFF2E2626),
      ),
    ),

    // 2) Soft Glam
    MakeupLookPreset.softGlam: _LookPalette(
      baseIntensity: 0.58,
      glossy: false,
      eyeliner: EyelinerStyle.subtle,
      warm: const _LookVariant(
        lipColor: Color(0xCCB87962),
        blushColor: Color(0x66F0B08A),
        eyeshadowColor: Color(0xFFC7A06B),
        browColor: Color(0xFF3B2E26),
      ),
      cool: const _LookVariant(
        lipColor: Color(0xCC9B6B7F),
        blushColor: Color(0x668E6D86),
        eyeshadowColor: Color(0xFFB08DA4),
        browColor: Color(0xFF2E2A33),
      ),
      neutral: const _LookVariant(
        lipColor: Color(0xCCB46A6A),
        blushColor: Color(0x66EFB2A4),
        eyeshadowColor: Color(0xFFB99A86),
        browColor: Color(0xFF332D2D),
      ),
    ),

    // 3) Doll / K-Beauty
    MakeupLookPreset.dollKBeauty: _LookPalette(
      baseIntensity: 0.38,
      glossy: true,
      eyeliner: EyelinerStyle.thin,
      warm: const _LookVariant(
        lipColor: Color(0xCCB57A62),
        blushColor: Color(0x66F2A38B),
        eyeshadowColor: Color(0xFFE8D2B9),
        browColor: Color(0xFF3A312B),
      ),
      cool: const _LookVariant(
        lipColor: Color(0xCC946B8A),
        blushColor: Color(0x669B6B8B),
        eyeshadowColor: Color(0xFFE1D1E4),
        browColor: Color(0xFF2F2B36),
      ),
      neutral: const _LookVariant(
        lipColor: Color(0xCCA86F7A),
        blushColor: Color(0x66E9A7B6),
        eyeshadowColor: Color(0xFFE7D8D1),
        browColor: Color(0xFF343030),
      ),
    ),

    // 4) Bronzed Goddess
    MakeupLookPreset.bronzedGoddess: _LookPalette(
      baseIntensity: 0.72,
      glossy: false,
      eyeliner: EyelinerStyle.subtle,
      warm: const _LookVariant(
        lipColor: Color(0xCC9B5A3A),
        blushColor: Color(0x66A45B2A),
        eyeshadowColor: Color(0xFFD08A3A),
        browColor: Color(0xFF2E2119),
      ),
      cool: const _LookVariant(
        lipColor: Color(0xCC8C5868),
        blushColor: Color(0x667A4A5A),
        eyeshadowColor: Color(0xFFB07A63),
        browColor: Color(0xFF2A242E),
      ),
      neutral: const _LookVariant(
        lipColor: Color(0xCC9A5C4A),
        blushColor: Color(0x668D5A3B),
        eyeshadowColor: Color(0xFFC58F54),
        browColor: Color(0xFF2B2322),
      ),
    ),

    // 5) Bold Editorial
    MakeupLookPreset.boldEditorial: _LookPalette(
      baseIntensity: 0.90,
      glossy: false,
      eyeliner: EyelinerStyle.emoWing, // graphic fallback
      warm: const _LookVariant(
        lipColor: Color(0xFF7A1F1B),
        blushColor: Color(0x668B3B2A),
        eyeshadowColor: Color(0xFF8B2A1E),
        browColor: Color(0xFF2B1F1A),
      ),
      cool: const _LookVariant(
        lipColor: Color(0xFF3E1648),
        blushColor: Color(0x663C3F86),
        eyeshadowColor: Color(0xFF213A7A),
        browColor: Color(0xFF221F2A),
      ),
      neutral: const _LookVariant(
        lipColor: Color(0xFF5B1C3D),
        blushColor: Color(0x667A3D6B),
        eyeshadowColor: Color(0xFF3B2B66),
        browColor: Color(0xFF241F26),
      ),
    ),

    // 6) Debug preset: non-adaptive, brows LIGHT BROWN
    MakeupLookPreset.debugPainterTest: _LookPalette(
      baseIntensity: 1.0,
      glossy: true,
      eyeliner: EyelinerStyle.emoWing,
      warm: const _LookVariant(
        lipColor: Color(0xFFFF0000),
        blushColor: Color(0xFFFF00FF),
        eyeshadowColor: Color(0xFF0000FF),
        browColor: Color(0xFFB07A4A), // ✅ light brown
      ),
      cool: const _LookVariant(
        lipColor: Color(0xFFFF0000),
        blushColor: Color(0xFFFF00FF),
        eyeshadowColor: Color(0xFF0000FF),
        browColor: Color(0xFFB07A4A),
      ),
      neutral: const _LookVariant(
        lipColor: Color(0xFFFF0000),
        blushColor: Color(0xFFFF00FF),
        eyeshadowColor: Color(0xFF0000FF),
        browColor: Color(0xFFB07A4A),
      ),
    ),
  };

  static _LookVariant _variantFor(MakeupLookPreset preset, FaceProfile? profile) {
    final pal = _palettes[preset] ?? _palettes[MakeupLookPreset.softGlam]!;
    if (preset == MakeupLookPreset.debugPainterTest) return pal.neutral;

    final key = _undertoneKey(profile);
    switch (key) {
      case Undertone.warm:
        return pal.warm;
      case Undertone.cool:
        return pal.cool;
      case Undertone.neutral:
        return pal.neutral;
    }
  }

  /// ✅ API kept: configFromPreset(...)
  static MakeupLookConfig configFromPreset(
    MakeupLookPreset preset, {
    FaceProfile? profile,
  }) {
    final pal = _palettes[preset] ?? _palettes[MakeupLookPreset.softGlam]!;
    final v = _variantFor(preset, profile);

    double intensity = pal.baseIntensity;
    if (preset != MakeupLookPreset.debugPainterTest && _lowSkinConfidence(profile)) {
      intensity = (intensity * 0.88).clamp(0.0, 1.0);
    }

    return MakeupLookConfig(
      lipColor: v.lipColor,
      blushColor: v.blushColor,
      eyeshadowColor: v.eyeshadowColor,
      eyelinerStyle: pal.eyeliner,
      intensity: intensity,
      glossyLips: pal.glossy,
    );
  }

  /// ✅ NEW: Palette-driven brow color accessor (Option B)
  static Color browColorFromPreset(
    MakeupLookPreset preset, {
    FaceProfile? profile,
  }) {
    final v = _variantFor(preset, profile);
    return v.browColor;
  }

  /// ✅ API kept: fromPreset(...)
  /// Face shape affects steps only (NOT colors)
  static LookResult fromPreset(
    MakeupLookPreset preset, {
    FaceProfile? profile,
  }) {
    final cfg = configFromPreset(preset, profile: profile);
    final shape = profile?.faceShape ?? FaceShape.unknown;

    final forcedNeutral = profile != null && profile.undertoneConfidence < _minUndertoneConfidence;
    final undertoneNote = _undertoneNote(_undertoneKey(profile), forcedNeutral: forcedNeutral);
    final confidenceNote = _confidenceNote(profile);

    final blushPlacement = _blushPlacement(shape);
    final eyePlacement = _eyePlacement(shape, preset);
    final editorialBlush = _editorialBlushPlacement(shape);

    switch (preset) {
      case MakeupLookPreset.emo:
        return LookResult(
          lookName: 'Emo',
          lipstickColor: cfg.lipColor,
          blushColor: cfg.blushColor,
          eyeshadowColor: cfg.eyeshadowColor,
          steps: [
            'Eyeshadow: smoky charcoal—pack near lash line then blend upward.',
            eyePlacement,
            'Eyeliner: emo wing (bold outer lift).',
            'Blush: minimal—keep cheeks neutral.',
            'Brows: slightly straighter vibe, soft but defined (instruction only).',
            'Lips: deep berry/plum (wearable, not pure black).',
            undertoneNote,
            confidenceNote,
          ],
        );

      case MakeupLookPreset.softGlam:
        return LookResult(
          lookName: 'Soft Glam',
          lipstickColor: cfg.lipColor,
          blushColor: cfg.blushColor,
          eyeshadowColor: cfg.eyeshadowColor,
          steps: [
            'Eyeshadow: warm brown/champagne wash + soft depth on outer corner.',
            eyePlacement,
            'Blush: peachy + diffused for a smooth gradient.',
            blushPlacement,
            'Eyeliner: subtle (defined, not heavy).',
            'Brows: defined but soft—avoid harsh blocks (instruction only).',
            undertoneNote,
            confidenceNote,
          ],
        );

      case MakeupLookPreset.dollKBeauty:
        return LookResult(
          lookName: 'Doll / K-Beauty',
          lipstickColor: cfg.lipColor,
          blushColor: cfg.blushColor,
          eyeshadowColor: cfg.eyeshadowColor,
          steps: [
            'Eyeshadow: light, soft wash (keep it airy).',
            'Eyeliner: thin (no heavy wing).',
            'Blush: rosy + higher placement for that “doll” effect.',
            _kBeautyBlushPlacement(shape),
            'Brows (instruction only): aim for a straighter, softer brow vibe.',
            undertoneNote,
            confidenceNote,
          ],
        );

      case MakeupLookPreset.bronzedGoddess:
        return LookResult(
          lookName: 'Bronzed Goddess',
          lipstickColor: cfg.lipColor,
          blushColor: cfg.blushColor,
          eyeshadowColor: cfg.eyeshadowColor,
          steps: [
            'Eyeshadow: gold/copper glow—focus shimmer on lid, deepen outer edge.',
            eyePlacement,
            'Cheeks: warmer blush/bronzer vibe with more presence.',
            blushPlacement,
            'Eyeliner: subtle or thin to keep the bronzed look clean.',
            'Brows: slightly deeper/stronger to balance bronzed tones (instruction only).',
            undertoneNote,
            confidenceNote,
          ],
        );

      case MakeupLookPreset.boldEditorial:
        return LookResult(
          lookName: 'Bold Editorial',
          lipstickColor: cfg.lipColor,
          blushColor: cfg.blushColor,
          eyeshadowColor: cfg.eyeshadowColor,
          steps: [
            'Eyeshadow: unconventional color statement—keep edges intentional.',
            eyePlacement,
            'Eyeliner: graphic/dramatic (using emo wing style).',
            'Blush: stronger contrast—think “editorial structure,” not softness.',
            editorialBlush,
            undertoneNote,
            confidenceNote,
          ],
        );

      case MakeupLookPreset.debugPainterTest:
        return const LookResult(
          lookName: '🔧 Debug Painter Test',
          lipstickColor: Color(0xFFFF0000),
          blushColor: Color.fromARGB(102, 255, 112, 195), // ✅ soft pink w/ alpha (smooth on camera)
          eyeshadowColor: Color(0xFF0000FF),
          steps: [
            'This is a DEBUG mode to test all painters.',
            'All makeup elements should be visible:',
            '- Bright red lips',
            '- Bright magenta blush',
            '- Bright blue eyeshadow',
            '- Dramatic emo-wing eyeliner',
            '- Brows should be LIGHT BROWN for placement checking',
            'Use this to verify all painters are working.',
          ],
        );
    }
  }

  // ---------------------------
  // FACE-SHAPE PLACEMENT NOTES
  // ---------------------------

  static String _blushPlacement(FaceShape faceShape) {
    switch (faceShape) {
      case FaceShape.round:
        return 'Blush placement: slightly higher and outward to lift.';
      case FaceShape.square:
        return 'Blush placement: soften corners by blending diffused and diagonal.';
      case FaceShape.heart:
        return 'Blush placement: focus on outer cheeks, keep center soft.';
      case FaceShape.oval:
        return 'Blush placement: classic apples → blend up.';
      case FaceShape.unknown:
        return 'Blush placement: apply on apples and blend upward softly.';
    }
  }

  static String _kBeautyBlushPlacement(FaceShape faceShape) {
    switch (faceShape) {
      case FaceShape.round:
        return 'Blush placement (K-Beauty): high on upper cheek, pulled outward for lift.';
      case FaceShape.square:
        return 'Blush placement (K-Beauty): high + softly diffused to soften angles.';
      case FaceShape.heart:
        return 'Blush placement (K-Beauty): high on outer cheeks; keep center airy.';
      case FaceShape.oval:
        return 'Blush placement (K-Beauty): high on cheekbones for a youthful flush.';
      case FaceShape.unknown:
        return 'Blush placement (K-Beauty): keep it higher on the cheekbones, very soft blend.';
    }
  }

  static String _editorialBlushPlacement(FaceShape faceShape) {
    switch (faceShape) {
      case FaceShape.round:
        return 'Blush placement (Editorial): sharper diagonal up toward temples to sculpt and lift.';
      case FaceShape.square:
        return 'Blush placement (Editorial): angled but softly blended to avoid harsh jaw emphasis.';
      case FaceShape.heart:
        return 'Blush placement (Editorial): angular sweep on outer cheeks; keep center minimal.';
      case FaceShape.oval:
        return 'Blush placement (Editorial): defined diagonal along cheekbone, then soften the edge.';
      case FaceShape.unknown:
        return 'Blush placement (Editorial): place higher on cheekbone with a clean diagonal direction.';
    }
  }

  static String _eyePlacement(FaceShape faceShape, MakeupLookPreset preset) {
    final isDramatic = preset == MakeupLookPreset.emo || preset == MakeupLookPreset.boldEditorial;
    switch (faceShape) {
      case FaceShape.round:
        return isDramatic
            ? 'Eye placement: build depth on the outer third + extend slightly outward for lift.'
            : 'Eye placement: keep shadow pulled slightly outward (outer third) to elongate.';
      case FaceShape.square:
        return isDramatic
            ? 'Eye placement: keep edges blended/soft (avoid too sharp) to soften angles.'
            : 'Eye placement: use softer outer blending; keep liner subtle for a softer shape.';
      case FaceShape.heart:
        return 'Eye placement: emphasize outer corner, keep inner corner lighter.';
      case FaceShape.oval:
        return 'Eye placement: balanced—outer corner depth + smooth blend.';
      case FaceShape.unknown:
        return 'Eye placement: focus on outer corner depth with a soft blend upward.';
    }
  }

  static String _undertoneNote(Undertone u, {required bool forcedNeutral}) {
    if (forcedNeutral) {
      return 'Undertone: uncertain → using neutral/balanced shades for safer camera results.';
    }
    switch (u) {
      case Undertone.warm:
        return 'Undertone: warm → leaning peach/gold/copper where it fits the look.';
      case Undertone.cool:
        return 'Undertone: cool → leaning rose/mauve/plum where it fits the look.';
      case Undertone.neutral:
        return 'Undertone: neutral → using balanced shades.';
    }
  }

  static String _confidenceNote(FaceProfile? p) {
    if (p == null) return 'Profile: no analysis → using default settings.';
    if (!_lowSkinConfidence(p)) return 'Skin confidence: good → using full look intensity.';
    return 'Skin confidence: low → slightly reduced intensity to blend more naturally.';
  }

  // ---------------------------
  // PUBLIC API HELPERS (KEPT)
  // ---------------------------

  static EyelinerStyle eyelinerStyleFromPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return EyelinerStyle.subtle;
      case MakeupLookPreset.dollKBeauty:
        return EyelinerStyle.thin;
      case MakeupLookPreset.bronzedGoddess:
        return EyelinerStyle.subtle;
      case MakeupLookPreset.emo:
        return EyelinerStyle.emoWing;
      case MakeupLookPreset.boldEditorial:
        return EyelinerStyle.emoWing;
      case MakeupLookPreset.debugPainterTest:
        return EyelinerStyle.emoWing;
    }
  }

  static String blushStyleFromPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.dollKBeauty:
        return 'high';
      case MakeupLookPreset.softGlam:
        return 'diffused';
      case MakeupLookPreset.bronzedGoddess:
        return 'bronzed';
      case MakeupLookPreset.emo:
        return 'minimal';
      case MakeupLookPreset.boldEditorial:
        return 'angular';
      case MakeupLookPreset.debugPainterTest:
        return 'bold';
    }
  }
}

// ---------------------------
// INTERNAL (NO NEW FILES)
// ---------------------------

class _LookVariant {
  final Color lipColor;
  final Color blushColor;
  final Color eyeshadowColor;
  final Color browColor;

  const _LookVariant({
    required this.lipColor,
    required this.blushColor,
    required this.eyeshadowColor,
    required this.browColor,
  });
}

class _LookPalette {
  final _LookVariant warm;
  final _LookVariant cool;
  final _LookVariant neutral;

  final double baseIntensity;
  final bool glossy;
  final EyelinerStyle eyeliner;

  const _LookPalette({
    required this.warm,
    required this.cool,
    required this.neutral,
    required this.baseIntensity,
    required this.glossy,
    required this.eyeliner,
  });
}

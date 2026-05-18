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

// ✅ Presets: full list with all options
enum MakeupLookPreset {
  emo,
  softGlam,
  dollKBeauty,
  bronzedGoddess,
  boldEditorial,

  cleanGirl,
  coquette,
  strawberryMakeup,
  peachGirl,
  glassSkin,
  naturalNude,
  noMakeupMakeup,
  oldMoney,
  goldenGoddess,
  arabGlam,
  bridalGlam,
  victoriaSecretGlam,
  partyGlam,
  douyin,
  latteMakeup,
  cherryCola,
  coldGirlMakeup,
  monochromePink,
  eGirl,
  smokeyEyes,

  debugPainterTest,
}

// ✅ Updated label extension
extension MakeupLookPresetLabel on MakeupLookPreset {
  String get label {
    switch (this) {
      case MakeupLookPreset.softGlam:
        return 'Soft Glam';
      case MakeupLookPreset.dollKBeauty:
        return 'K-Beauty';
      case MakeupLookPreset.emo:
        return 'Emo';
      case MakeupLookPreset.bronzedGoddess:
        return 'Bronzed Goddess';
      case MakeupLookPreset.boldEditorial:
        return 'Bold Editorial';

      case MakeupLookPreset.cleanGirl:
        return 'Clean Girl';
      case MakeupLookPreset.coquette:
        return 'Coquette';
      case MakeupLookPreset.strawberryMakeup:
        return 'Strawberry Makeup';
      case MakeupLookPreset.peachGirl:
        return 'Peach Girl';
      case MakeupLookPreset.glassSkin:
        return 'Glass Skin';
      case MakeupLookPreset.naturalNude:
        return 'Natural Nude';
      case MakeupLookPreset.noMakeupMakeup:
        return 'No Makeup Makeup';
      case MakeupLookPreset.oldMoney:
        return 'Old Money';
      case MakeupLookPreset.goldenGoddess:
        return 'Golden Goddess';
      case MakeupLookPreset.arabGlam:
        return 'Arab Glam';
      case MakeupLookPreset.bridalGlam:
        return 'Bridal Glam';
      case MakeupLookPreset.victoriaSecretGlam:
        return 'Victoria Secret Glam';
      case MakeupLookPreset.partyGlam:
        return 'Party Glam';
      case MakeupLookPreset.douyin:
        return 'Douyin';
      case MakeupLookPreset.latteMakeup:
        return 'Latte Makeup';
      case MakeupLookPreset.cherryCola:
        return 'Cherry Cola';
      case MakeupLookPreset.coldGirlMakeup:
        return 'Cold Girl Makeup';
      case MakeupLookPreset.monochromePink:
        return 'Monochrome Pink';
      case MakeupLookPreset.eGirl:
        return 'E-Girl';
      case MakeupLookPreset.smokeyEyes:
        return 'Smokey Eyes';

      case MakeupLookPreset.debugPainterTest:
        return 'Debug Painter Test';
    }
  }
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

// ✅ Updated LookEngine class with all presets
class LookEngine {
  /// ✅ MAIN GENERATOR (updated with all presets)
  static LookResult generateLook({
    required FaceProfile profile,
    required MakeupLookPreset preset,
  }) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return LookResult(
          lookName: 'Soft Glam',
          lipstickColor: const Color(0xFFD86A7F),
          blushColor: const Color(0xFFFF9DAA),
          eyeshadowColor: const Color(0xFFBFA6A0),
          steps: [
            'Apply a light eyeshadow base all over the lid.',
            'Blend a medium shade into the crease.',
            'Add a darker shade to the outer corner for depth.',
            'Apply blush to the apples of the cheeks.',
            'Finish with a soft pink lipstick.',
          ],
        );

      case MakeupLookPreset.emo:
        return LookResult(
          lookName: 'Emo',
          lipstickColor: const Color(0xFF5A0F1C),
          blushColor: const Color(0xFF7A1F2B),
          eyeshadowColor: const Color(0xFF2B1B1B),
          steps: [
            'Apply dark smoky eyeshadow all over the lid.',
            'Blend upward for a gradient effect.',
            'Apply dramatic eyeliner with a wing.',
            'Keep blush minimal and muted.',
            'Finish with dark berry lipstick.',
          ],
        );

      case MakeupLookPreset.dollKBeauty:
        return LookResult(
          lookName: 'Doll / K-Beauty',
          lipstickColor: const Color(0xFFFFB7C5),
          blushColor: const Color(0xFFFFC0CB),
          eyeshadowColor: const Color(0xFFF5E6E8),
          steps: [
            'Apply light, shimmery eyeshadow all over the lid.',
            'Use a soft pink blush on the upper cheeks.',
            'Apply thin, natural eyeliner.',
            'Finish with gradient lip color.',
          ],
        );

      case MakeupLookPreset.bronzedGoddess:
        return LookResult(
          lookName: 'Bronzed Goddess',
          lipstickColor: const Color(0xFFD4A373),
          blushColor: const Color(0xFFE6B89C),
          eyeshadowColor: const Color(0xFFC49A6C),
          steps: [
            'Apply bronze/gold eyeshadow on the lid.',
            'Warm up the crease with a terracotta shade.',
            'Apply bronzer/blush hybrid to cheeks.',
            'Finish with warm nude lipstick.',
          ],
        );

      case MakeupLookPreset.boldEditorial:
        return LookResult(
          lookName: 'Bold Editorial',
          lipstickColor: const Color(0xFFE63946),
          blushColor: const Color(0xFFFF6B6B),
          eyeshadowColor: const Color(0xFF457B9D),
          steps: [
            'Apply bold, graphic eyeshadow design.',
            'Use strong, sculpted blush placement.',
            'Apply dramatic, graphic eyeliner.',
            'Finish with bold, statement lip color.',
          ],
        );

      case MakeupLookPreset.cleanGirl:
        return const LookResult(
          lookName: 'Clean Girl',
          lipstickColor: Color(0xFFD9908F),
          blushColor: Color(0xFFFFB5B8),
          eyeshadowColor: Color(0xFFE8D6CC),
          steps: [
            'Use a barely-there neutral eyeshadow wash.',
            'Keep eyeliner soft and close to the lash line.',
            'Apply fresh pink blush high on the cheeks.',
            'Finish with a glossy nude-pink lip.',
          ],
        );

      case MakeupLookPreset.coquette:
        return const LookResult(
          lookName: 'Coquette',
          lipstickColor: Color(0xFFE78FA7),
          blushColor: Color(0xFFFFAFC7),
          eyeshadowColor: Color(0xFFF3D6DE),
          steps: [
            'Apply soft pink eyeshadow across the lid.',
            'Add a delicate wing or thin liner.',
            'Place rosy blush high for a doll-like effect.',
            'Finish with a soft pink lip tint.',
          ],
        );

      case MakeupLookPreset.strawberryMakeup:
        return const LookResult(
          lookName: 'Strawberry Makeup',
          lipstickColor: Color(0xFFE85D75),
          blushColor: Color(0xFFFF7F8F),
          eyeshadowColor: Color(0xFFF6B1B8),
          steps: [
            'Use a soft rosy wash on the eyelids.',
            'Apply strawberry pink blush across the cheeks.',
            'Keep eyeliner very natural.',
            'Finish with juicy berry-pink lips.',
          ],
        );

      case MakeupLookPreset.peachGirl:
        return const LookResult(
          lookName: 'Peach Girl',
          lipstickColor: Color(0xFFFF9A76),
          blushColor: Color(0xFFFFB38A),
          eyeshadowColor: Color(0xFFF2B28A),
          steps: [
            'Apply peachy eyeshadow on the lids.',
            'Blend warm peach blush on the cheeks.',
            'Use soft brown eyeliner.',
            'Finish with a peach nude lip.',
          ],
        );

      case MakeupLookPreset.glassSkin:
        return const LookResult(
          lookName: 'Glass Skin',
          lipstickColor: Color(0xFFE8A3A3),
          blushColor: Color(0xFFFFC2C2),
          eyeshadowColor: Color(0xFFF5E7E2),
          steps: [
            'Keep the eyes very soft and luminous.',
            'Apply sheer blush for a hydrated look.',
            'Avoid heavy eyeliner.',
            'Finish with a glossy natural lip.',
          ],
        );

      case MakeupLookPreset.naturalNude:
        return const LookResult(
          lookName: 'Natural Nude',
          lipstickColor: Color(0xFFC98F7A),
          blushColor: Color(0xFFE5A996),
          eyeshadowColor: Color(0xFFD8B8A8),
          steps: [
            'Use a neutral beige eyeshadow base.',
            'Apply soft nude blush lightly.',
            'Define the eyes with subtle liner.',
            'Finish with a warm nude lipstick.',
          ],
        );

      case MakeupLookPreset.noMakeupMakeup:
        return const LookResult(
          lookName: 'No Makeup Makeup',
          lipstickColor: Color(0xFFD9A09A),
          blushColor: Color(0xFFF2B6AD),
          eyeshadowColor: Color(0xFFE9D5C9),
          steps: [
            'Use minimal eyeshadow close to your skin tone.',
            'Apply a very soft natural blush.',
            'Skip heavy liner and keep definition soft.',
            'Finish with a natural lip tint.',
          ],
        );

      case MakeupLookPreset.oldMoney:
        return const LookResult(
          lookName: 'Old Money',
          lipstickColor: Color(0xFFB87768),
          blushColor: Color(0xFFD99A8A),
          eyeshadowColor: Color(0xFFC9A58D),
          steps: [
            'Use elegant neutral brown eyeshadow.',
            'Keep eyeliner clean and refined.',
            'Apply muted blush for subtle structure.',
            'Finish with a classic rose-nude lip.',
          ],
        );

      case MakeupLookPreset.goldenGoddess:
        return const LookResult(
          lookName: 'Golden Goddess',
          lipstickColor: Color(0xFFD19A5F),
          blushColor: Color(0xFFE7A96B),
          eyeshadowColor: Color(0xFFD9A441),
          steps: [
            'Apply golden shimmer on the eyelids.',
            'Warm the crease with bronze shadow.',
            'Use sun-kissed blush placement.',
            'Finish with a golden nude lip.',
          ],
        );

      case MakeupLookPreset.arabGlam:
        return const LookResult(
          lookName: 'Arab Glam',
          lipstickColor: Color(0xFFB85C63),
          blushColor: Color(0xFFD67C7C),
          eyeshadowColor: Color(0xFF8B5E3C),
          steps: [
            'Apply warm brown shadow with strong depth.',
            'Create a dramatic lifted eyeliner shape.',
            'Sculpt the cheeks with structured blush.',
            'Finish with a bold rose-brown lip.',
          ],
        );

      case MakeupLookPreset.bridalGlam:
        return const LookResult(
          lookName: 'Bridal Glam',
          lipstickColor: Color(0xFFD98C8C),
          blushColor: Color(0xFFFFA7B3),
          eyeshadowColor: Color(0xFFE8C7A8),
          steps: [
            'Apply champagne shimmer on the lids.',
            'Blend soft brown into the crease.',
            'Use romantic pink blush.',
            'Finish with a polished rose nude lip.',
          ],
        );

      case MakeupLookPreset.victoriaSecretGlam:
        return const LookResult(
          lookName: 'Victoria Secret Glam',
          lipstickColor: Color(0xFFD17A8A),
          blushColor: Color(0xFFFF9AAA),
          eyeshadowColor: Color(0xFFC9A06A),
          steps: [
            'Apply bronzy shimmer on the eyelids.',
            'Use lifted soft wing eyeliner.',
            'Apply warm pink blush for a healthy glow.',
            'Finish with a glossy pink nude lip.',
          ],
        );

      case MakeupLookPreset.partyGlam:
        return const LookResult(
          lookName: 'Party Glam',
          lipstickColor: Color(0xFFC94F6D),
          blushColor: Color(0xFFFF7890),
          eyeshadowColor: Color(0xFF9C6ADE),
          steps: [
            'Apply shimmer or metallic eyeshadow.',
            'Add stronger eyeliner definition.',
            'Use vibrant blush placement.',
            'Finish with a statement lip color.',
          ],
        );

      case MakeupLookPreset.douyin:
        return const LookResult(
          lookName: 'Douyin',
          lipstickColor: Color(0xFFFF6F91),
          blushColor: Color(0xFFFF9AB3),
          eyeshadowColor: Color(0xFFF6C5D0),
          steps: [
            'Apply soft pink shimmer around the eyes.',
            'Use lifted eyeliner with a delicate wing.',
            'Place blush under the eyes and upper cheeks.',
            'Finish with a gradient glossy lip.',
          ],
        );

      case MakeupLookPreset.latteMakeup:
        return const LookResult(
          lookName: 'Latte Makeup',
          lipstickColor: Color(0xFFC0835C),
          blushColor: Color(0xFFD49A76),
          eyeshadowColor: Color(0xFFB98055),
          steps: [
            'Apply warm coffee-brown eyeshadow.',
            'Blend caramel tones into the crease.',
            'Use bronzy blush placement.',
            'Finish with a creamy brown nude lip.',
          ],
        );

      case MakeupLookPreset.cherryCola:
        return const LookResult(
          lookName: 'Cherry Cola',
          lipstickColor: Color(0xFF8F1D2C),
          blushColor: Color(0xFFC44A5A),
          eyeshadowColor: Color(0xFF7A2E35),
          steps: [
            'Apply burgundy-brown eyeshadow softly.',
            'Define the eyes with dark liner.',
            'Use berry blush sparingly.',
            'Finish with a cherry cola lip.',
          ],
        );

      case MakeupLookPreset.coldGirlMakeup:
        return const LookResult(
          lookName: 'Cold Girl Makeup',
          lipstickColor: Color(0xFFD97991),
          blushColor: Color(0xFFFF8FA8),
          eyeshadowColor: Color(0xFFE8D6E6),
          steps: [
            'Use cool-toned pink eyeshadow softly.',
            'Apply blush across the nose and cheeks.',
            'Keep eyeliner thin and natural.',
            'Finish with a cool pink lip.',
          ],
        );

      case MakeupLookPreset.monochromePink:
        return const LookResult(
          lookName: 'Monochrome Pink',
          lipstickColor: Color(0xFFE36B8D),
          blushColor: Color(0xFFFF8FB0),
          eyeshadowColor: Color(0xFFF3A8C2),
          steps: [
            'Use pink tones on the eyelids.',
            'Apply matching pink blush.',
            'Keep eyeliner soft to maintain harmony.',
            'Finish with a matching pink lip.',
          ],
        );

      case MakeupLookPreset.eGirl:
        return const LookResult(
          lookName: 'E-Girl',
          lipstickColor: Color(0xFFB8325A),
          blushColor: Color(0xFFFF5C8A),
          eyeshadowColor: Color(0xFFD66BA0),
          steps: [
            'Apply bold pink eyeshadow around the eyes.',
            'Use dramatic eyeliner with a strong wing.',
            'Apply blush across the cheeks and nose.',
            'Finish with a bold berry lip.',
          ],
        );

      case MakeupLookPreset.smokeyEyes:
        return const LookResult(
          lookName: 'Smokey Eyes',
          lipstickColor: Color(0xFF9C6B5B),
          blushColor: Color(0xFFC07A6A),
          eyeshadowColor: Color(0xFF3B2F2F),
          steps: [
            'Pack dark shadow near the lash line.',
            'Blend upward to create a smoky gradient.',
            'Use dark eyeliner for extra intensity.',
            'Finish with a muted nude-brown lip.',
          ],
        );

      case MakeupLookPreset.debugPainterTest:
        return const LookResult(
          lookName: 'Debug Painter Test',
          lipstickColor: Color(0xFFFF0000),
          blushColor: Color.fromARGB(102, 255, 112, 195),
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

  /// ✅ EYELINER STYLE (used by overlay)
  static EyelinerStyle eyelinerStyleFromPreset(
    MakeupLookPreset preset,
  ) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return EyelinerStyle.subtle;
      case MakeupLookPreset.emo:
        return EyelinerStyle.emoWing;
      case MakeupLookPreset.dollKBeauty:
        return EyelinerStyle.thin;
      case MakeupLookPreset.bronzedGoddess:
        return EyelinerStyle.subtle;
      case MakeupLookPreset.boldEditorial:
        return EyelinerStyle.emoWing;
      case MakeupLookPreset.cleanGirl:
        return EyelinerStyle.thin;
      case MakeupLookPreset.coquette:
        return EyelinerStyle.thin;
      case MakeupLookPreset.strawberryMakeup:
        return EyelinerStyle.subtle;
      case MakeupLookPreset.peachGirl:
        return EyelinerStyle.thin;
      case MakeupLookPreset.glassSkin:
        return EyelinerStyle.none;
      case MakeupLookPreset.naturalNude:
        return EyelinerStyle.thin;
      case MakeupLookPreset.noMakeupMakeup:
        return EyelinerStyle.none;
      case MakeupLookPreset.oldMoney:
        return EyelinerStyle.subtle;
      case MakeupLookPreset.goldenGoddess:
        return EyelinerStyle.thin;
      case MakeupLookPreset.arabGlam:
        return EyelinerStyle.emoWing;
      case MakeupLookPreset.bridalGlam:
        return EyelinerStyle.subtle;
      case MakeupLookPreset.victoriaSecretGlam:
        return EyelinerStyle.subtle;
      case MakeupLookPreset.partyGlam:
        return EyelinerStyle.emoWing;
      case MakeupLookPreset.douyin:
        return EyelinerStyle.thin;
      case MakeupLookPreset.latteMakeup:
        return EyelinerStyle.subtle;
      case MakeupLookPreset.cherryCola:
        return EyelinerStyle.emoWing;
      case MakeupLookPreset.coldGirlMakeup:
        return EyelinerStyle.thin;
      case MakeupLookPreset.monochromePink:
        return EyelinerStyle.thin;
      case MakeupLookPreset.eGirl:
        return EyelinerStyle.emoWing;
      case MakeupLookPreset.smokeyEyes:
        return EyelinerStyle.emoWing;
      case MakeupLookPreset.debugPainterTest:
        return EyelinerStyle.emoWing;
    }
  }

  /// ✅ BROW COLOR (used by brow painter)
  static Color browColorFromPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.emo:
        return const Color(0xFF1A1A1A);
      case MakeupLookPreset.dollKBeauty:
        return const Color(0xFF5D4037);
      case MakeupLookPreset.bronzedGoddess:
        return const Color(0xFF4E342E);
      case MakeupLookPreset.boldEditorial:
        return const Color(0xFF3E2723);
      case MakeupLookPreset.cleanGirl:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.coquette:
        return const Color(0xFF5D4037);
      case MakeupLookPreset.strawberryMakeup:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.peachGirl:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.glassSkin:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.naturalNude:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.noMakeupMakeup:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.oldMoney:
        return const Color(0xFF5D4037);
      case MakeupLookPreset.goldenGoddess:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.arabGlam:
        return const Color(0xFF1A1A1A);
      case MakeupLookPreset.bridalGlam:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.victoriaSecretGlam:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.partyGlam:
        return const Color(0xFF3E2723);
      case MakeupLookPreset.douyin:
        return const Color(0xFF5D4037);
      case MakeupLookPreset.latteMakeup:
        return const Color(0xFF6D4C41);
      case MakeupLookPreset.cherryCola:
        return const Color(0xFF1A1A1A);
      case MakeupLookPreset.coldGirlMakeup:
        return const Color(0xFF5D4037);
      case MakeupLookPreset.monochromePink:
        return const Color(0xFF5D4037);
      case MakeupLookPreset.eGirl:
        return const Color(0xFF1A1A1A);
      case MakeupLookPreset.smokeyEyes:
        return const Color(0xFF1A1A1A);
      case MakeupLookPreset.debugPainterTest:
        return const Color(0xFFB07A4A); // Light brown for debug
    }
  }

  /// ✅ BLUSH STYLE (used by blush painter)
  static String blushStyleFromPreset(MakeupLookPreset preset) {
    switch (preset) {
      case MakeupLookPreset.softGlam:
        return 'soft';
      case MakeupLookPreset.emo:
        return 'sharp';
      case MakeupLookPreset.dollKBeauty:
        return 'soft';
      case MakeupLookPreset.bronzedGoddess:
        return 'warm';
      case MakeupLookPreset.boldEditorial:
        return 'sharp';
      case MakeupLookPreset.cleanGirl:
        return 'soft';
      case MakeupLookPreset.coquette:
        return 'soft';
      case MakeupLookPreset.strawberryMakeup:
        return 'bold';
      case MakeupLookPreset.peachGirl:
        return 'warm';
      case MakeupLookPreset.glassSkin:
        return 'soft';
      case MakeupLookPreset.naturalNude:
        return 'soft';
      case MakeupLookPreset.noMakeupMakeup:
        return 'soft';
      case MakeupLookPreset.oldMoney:
        return 'soft';
      case MakeupLookPreset.goldenGoddess:
        return 'warm';
      case MakeupLookPreset.arabGlam:
        return 'sharp';
      case MakeupLookPreset.bridalGlam:
        return 'soft';
      case MakeupLookPreset.victoriaSecretGlam:
        return 'warm';
      case MakeupLookPreset.partyGlam:
        return 'bold';
      case MakeupLookPreset.douyin:
        return 'soft';
      case MakeupLookPreset.latteMakeup:
        return 'warm';
      case MakeupLookPreset.cherryCola:
        return 'sharp';
      case MakeupLookPreset.coldGirlMakeup:
        return 'soft';
      case MakeupLookPreset.monochromePink:
        return 'soft';
      case MakeupLookPreset.eGirl:
        return 'bold';
      case MakeupLookPreset.smokeyEyes:
        return 'sharp';
      case MakeupLookPreset.debugPainterTest:
        return 'bold';
    }
  }
}
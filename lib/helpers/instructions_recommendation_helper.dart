import 'dart:math';
import 'package:flutter/material.dart';

bool skinToneMatchesShadeDepth(String skinTone, String shadeDepth) {
  final tone = skinTone.toLowerCase();
  final depth = shadeDepth.toLowerCase();

  if (tone.contains('fair')) {
    return depth.contains('fair') || depth.contains('light');
  }

  if (tone.contains('light')) {
    return depth.contains('light') ||
        depth.contains('fair') ||
        depth.contains('medium');
  }

  if (tone.contains('medium')) {
    return depth.contains('medium') ||
        depth.contains('morena') ||
        depth.contains('light');
  }

  if (tone.contains('morena') || tone.contains('tan')) {
    return depth.contains('morena') ||
        depth.contains('medium') ||
        depth.contains('deep morena');
  }

  if (tone.contains('deep') || tone.contains('dark')) {
    return depth.contains('deep morena') || depth.contains('morena');
  }

  return false;
}

String tipForTargetArea(String targetArea) {
  switch (targetArea) {
    case 'full_face':
      return 'Apply base products in thin layers. Focus on smooth prep before adding color so the makeup blends better.';
    case 'brows':
      return 'Start lightly on the inner brow, then build definition toward the arch and tail.';
    case 'eyeshadow':
      return 'Blend the edges first before adding more pigment.';
    case 'eyeliner':
      return 'Keep your hand steady and draw close to the lash line.';
    case 'blush_contour':
      return 'Apply blush little by little. Blend upward for a lifted look.';
    case 'lips':
      return 'Start from the center of the lips, then blend outward.';
    case 'full_makeup':
      return 'Check the balance of your eyes, cheeks, and lips.';
    default:
      return 'Follow the guide slowly and build product gradually.';
  }
}

int lookColorFamilyScore({
  required String lookName,
  required String targetArea,
  required String colorFamily,
}) {
  final look = lookName.toLowerCase();
  final area = targetArea.toLowerCase();
  final color = colorFamily.toLowerCase().trim();

  if (color.isEmpty) return -4;

  List<String> preferred = [];
  List<String> acceptable = [];
  List<String> badMismatch = [];

  if (look.contains('peach')) {
    preferred = ['soft peach', 'warm coral', 'orange coral', 'beige nude'];
    acceptable = ['terracotta', 'caramel nude', 'rosy pink'];
    badMismatch = [
      'plum',
      'wine red',
      'cool berry',
      'cherry red',
      'dusty mauve',
      'cool pink',
      'warm brown',
      'brown nude',
    ];
  } else if (look.contains('soft glam')) {
    preferred = [
      'muted rose',
      'rosy pink',
      'dusty mauve',
      'beige nude',
      'caramel nude',
    ];
    acceptable = ['soft peach', 'brown nude'];
    badMismatch = ['wine red', 'plum', 'cherry red', 'orange coral'];
  } else if (look.contains('douyin') || look.contains('k-beauty')) {
    preferred = ['cool pink', 'rosy pink', 'berry pink', 'soft peach'];
    acceptable = ['muted rose', 'dusty mauve'];
    badMismatch = ['warm brown', 'brown nude', 'terracotta', 'wine red'];
  } else if (look.contains('clean girl') || look.contains('glass skin')) {
    preferred = ['beige nude', 'muted rose', 'rosy pink', 'soft peach'];
    acceptable = ['caramel nude', 'cool pink'];
    badMismatch = ['wine red', 'plum', 'cherry red', 'warm brown'];
  } else {
    preferred = ['rosy pink', 'muted rose', 'beige nude', 'dusty mauve'];
    acceptable = ['soft peach', 'caramel nude'];
    badMismatch = ['plum', 'wine red', 'cherry red'];
  }

  final isPreferred = preferred.any((p) => color.contains(p));
  final isAcceptable = acceptable.any((p) => color.contains(p));
  final isBadMismatch = badMismatch.any((p) => color.contains(p));

  if (area == 'lips') {
    if (isPreferred) return 18;
    if (isAcceptable) return 2;
    if (isBadMismatch) return -30;
    return -10;
  }

  if (isPreferred) return 12;
  if (isAcceptable) return 5;
  if (isBadMismatch) return -18;

  if (area == 'blush_contour' || area == 'eyeshadow') {
    return -3;
  }

  return 0;
}

String categoryForTargetArea(String targetArea) {
  switch (targetArea) {
    case 'full_face':
      return 'Primer';
    case 'brows':
      return 'Eyebrow';
    case 'eyeshadow':
      return 'Eyeshadow';
    case 'eyeliner':
      return 'Eyeliner';
    case 'blush_contour':
      return 'Blush';
    case 'lips':
      return 'Lipstick';
    case 'full_makeup':
      return 'Setting Spray';
    default:
      return '';
  }
}

Color? colorFromHex(String? hex) {
  if (hex == null || hex.trim().isEmpty) return null;

  final cleaned = hex.replaceAll('#', '').trim();

  if (cleaned.length != 6) return null;

  try {
    return Color(int.parse('FF$cleaned', radix: 16));
  } catch (_) {
    return null;
  }
}

String hexFromColor(Color color) {
  return color.value.toRadixString(16).substring(2).toUpperCase();
}

String preferredColorFamilyForLook({
  required String lookName,
  required String targetArea,
}) {
  final look = lookName.toLowerCase();
  final area = targetArea.toLowerCase();

  if (area == 'lips') {
    if (look.contains('peach')) return 'soft peach';
    if (look.contains('clean girl') || look.contains('glass skin')) return 'muted rose';
    if (look.contains('douyin') || look.contains('k-beauty')) return 'rosy pink';
    if (look.contains('soft glam')) return 'muted rose';
    if (look.contains('latte') || look.contains('old money')) return 'brown nude';
    if (look.contains('bronzed') || look.contains('golden')) return 'terracotta';
    if (look.contains('emo') || look.contains('e-girl')) return 'cool berry';
    if (look.contains('cherry cola')) return 'wine red';
    if (look.contains('cold girl') || look.contains('monochrome pink')) return 'cool pink';
    if (look.contains('bridal')) return 'muted rose';
    if (look.contains('arab') || look.contains('party')) return 'wine red';

    return 'rosy pink';
  }

  if (area == 'blush_contour') {
    if (look.contains('peach')) return 'soft peach';
    if (look.contains('clean girl') || look.contains('glass skin')) return 'rosy pink';
    if (look.contains('douyin') || look.contains('k-beauty')) return 'cool pink';
    if (look.contains('soft glam')) return 'muted rose';
    if (look.contains('bronzed') || look.contains('golden')) return 'terracotta';

    return 'rosy pink';
  }

  if (area == 'eyeshadow') {
    if (look.contains('peach')) return 'warm coral';
    if (look.contains('latte') || look.contains('old money')) return 'warm brown';
    if (look.contains('soft glam')) return 'dusty mauve';
    if (look.contains('douyin') || look.contains('k-beauty')) return 'rosy pink';
    if (look.contains('bronzed') || look.contains('golden')) return 'terracotta';

    return 'brown nude';
  }

  return '';
}

Color fallbackColorForTargetArea({
  required String targetArea,
  required Color originalColor,
  required Map<String, Color> lockedColors,
}) {
  return lockedColors[targetArea] ?? originalColor;
}

// ===============================
// STRICT LIPSTICK AI MATCHING
// ===============================

bool containsAny(String value, List<String> keywords) {
  final lower = value.toLowerCase();

  return keywords.any(
    (keyword) => lower.contains(keyword.toLowerCase()),
  );
}

double hexColorDistance(String hex1, String hex2) {
  final c1 = colorFromHex(hex1);
  final c2 = colorFromHex(hex2);

  if (c1 == null || c2 == null) {
    return 9999;
  }

  final r = c1.red - c2.red;
  final g = c1.green - c2.green;
  final b = c1.blue - c2.blue;

  return sqrt((r * r) + (g * g) + (b * b));
}

double lipstickStrictScore({
  required Map<String, dynamic> product,
  required String lookName,
  required String recommendedHex,
  required String recommendedColorFamily,
  required String userUndertone,
  required String userSkinType,
  required String userShadeDepth,
}) {
  double score = 0;

  final productHex = (product['hex_code'] ?? '').toString().trim();

  final productFamily =
      (product['color_family'] ?? '').toString().toLowerCase();

  final productUndertone =
      (product['undertone'] ?? '').toString().toLowerCase();

  final productSkinType =
      (product['compatible_skin_type'] ?? '').toString().toLowerCase();

  final productShadeDepth =
      (product['shade_depth'] ?? '').toString().toLowerCase();

  final look = lookName.toLowerCase();
  final targetFamily = recommendedColorFamily.toLowerCase();
  final undertone = userUndertone.toLowerCase();
  final skinType = userSkinType.toLowerCase();
  final shadeDepth = userShadeDepth.toLowerCase();

  if (productHex.isNotEmpty && recommendedHex.isNotEmpty) {
    final distance = hexColorDistance(productHex, recommendedHex);

    if (distance <= 25) {
      score += 120;
    } else if (distance <= 45) {
      score += 90;
    } else if (distance <= 65) {
      score += 60;
    } else if (distance <= 90) {
      score += 20;
    } else {
      score -= 120;
    }
  }

  if (targetFamily.isNotEmpty) {
    if (productFamily.contains(targetFamily) ||
        targetFamily.contains(productFamily)) {
      score += 100;
    } else {
      score -= 80;
    }
  }

  if (look.contains('peach')) {
    if (containsAny(productFamily, [
      'peach',
      'coral',
      'warm pink',
      'soft pink',
      'rosy pink',
    ])) {
      score += 80;
    }

    if (containsAny(productFamily, [
      'wine',
      'berry',
      'plum',
      'brown',
      'cool berry',
    ])) {
      score -= 180;
    }
  }

  if (look.contains('clean girl') || look.contains('glass skin')) {
    if (containsAny(productFamily, [
      'nude',
      'soft pink',
      'rose',
      'peach',
      'rosy pink',
      'muted rose',
    ])) {
      score += 75;
    }

    if (containsAny(productFamily, [
      'wine',
      'berry',
      'plum',
      'brown',
      'deep red',
    ])) {
      score -= 170;
    }
  }

  if (look.contains('douyin') || look.contains('k-beauty')) {
    if (containsAny(productFamily, [
      'pink',
      'rose',
      'berry pink',
      'soft red',
      'cool pink',
      'rosy pink',
    ])) {
      score += 80;
    }

    if (containsAny(productFamily, [
      'brown',
      'warm brown',
      'terracotta',
      'wine',
      'brown nude',
    ])) {
      score -= 170;
    }
  }

  if (look.contains('soft glam')) {
    if (containsAny(productFamily, [
      'rose',
      'nude',
      'mauve',
      'pink brown',
      'soft brown',
      'muted rose',
      'rosy pink',
    ])) {
      score += 60;
    }
  }

  if (look.contains('editorial') || look.contains('bold')) {
    if (containsAny(productFamily, [
      'red',
      'wine',
      'berry',
      'plum',
    ])) {
      score += 70;
    }
  }

  if (undertone.isNotEmpty && productUndertone.contains(undertone)) {
    score += 35;
  } else if (undertone.isNotEmpty) {
    score -= 25;
  }

  if (skinType.isNotEmpty && productSkinType.contains(skinType)) {
    score += 15;
  }

  if (shadeDepth.isNotEmpty && productShadeDepth.contains(shadeDepth)) {
    score += 20;
  }

  return score;
}
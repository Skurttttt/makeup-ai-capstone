import 'dart:math';
import 'package:flutter/material.dart';

class PaletteMoodResult {
  final String mood;
  final String depth;
  final double warmth;
  final double saturation;
  final double contrast;
  final List<String> colorFamilies;

  const PaletteMoodResult({
    required this.mood,
    required this.depth,
    required this.warmth,
    required this.saturation,
    required this.contrast,
    required this.colorFamilies,
  });
}

class PaletteMoodEngine {
  static List<String> normalizeHexes({
    required String primaryHex,
    required List<String> extraHexes,
  }) {
    final rawHexes = [
      primaryHex,
      ...extraHexes,
    ];

    final seen = <String>{};
    final normalized = <String>[];

    for (final raw in rawHexes) {
      final hex = raw.trim().toUpperCase();

      if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(hex)) {
        continue;
      }

      if (seen.add(hex)) {
        normalized.add(hex);
      }
    }

    return normalized;
  }

  static PaletteMoodResult analyze(List<String> hexes) {
    final colors = hexes.map(_parseColor).whereType<Color>().toList();

    if (colors.isEmpty) {
      return const PaletteMoodResult(
        mood: 'soft neutral',
        depth: 'medium',
        warmth: 0,
        saturation: 0,
        contrast: 0,
        colorFamilies: [],
      );
    }

    final families = <String>[];
    final warmthValues = <double>[];
    final saturationValues = <double>[];
    final brightnessValues = <double>[];

    for (final color in colors) {
      final signals = _signals(color);

      warmthValues.add(signals.warmth);
      saturationValues.add(signals.saturation);
      brightnessValues.add(signals.brightness);
      families.add(_familyFromColor(color));
    }

    final warmth = _avg(warmthValues);
    final saturation = _avg(saturationValues);
    final minBrightness = brightnessValues.reduce(min);
    final maxBrightness = brightnessValues.reduce(max);
    final contrast = (maxBrightness - minBrightness).clamp(0.0, 1.0);
    final avgBrightness = _avg(brightnessValues);
    final depth = _depthFromBrightness(avgBrightness);

    final mood = _moodFromPalette(
      families: families,
      warmth: warmth,
      saturation: saturation,
      contrast: contrast,
      depth: depth,
    );

    return PaletteMoodResult(
      mood: mood,
      depth: depth,
      warmth: warmth,
      saturation: saturation,
      contrast: contrast,
      colorFamilies: families,
    );
  }

  // REPLACED: Complete scoring method with group-based scoring
  static int scoreProductForLook({
    required Map<String, dynamic> product,
    required String selectedLook,
    required String targetArea,
  }) {
    final isMultiPalette = product['is_multi_palette'] == true;

    if (!isMultiPalette) return 0;

    final look = selectedLook.toLowerCase().trim();
    final area = targetArea.toLowerCase().trim();

    final mood = product['palette_mood']?.toString().toLowerCase().trim() ?? '';
    final depth = product['palette_depth']?.toString().toLowerCase().trim() ?? '';
    final warmth = (product['palette_warmth'] as num?)?.toDouble() ?? 0.0;
    final saturation =
        (product['palette_saturation'] as num?)?.toDouble() ?? 0.0;
    final contrast = (product['palette_contrast'] as num?)?.toDouble() ?? 0.0;

    var score = 0;

    if (area.contains('eye') ||
        area.contains('shadow') ||
        area.contains('contour')) {
      score += 20;
    }

    final group = _lookMoodGroup(look);

    score += _moodGroupScore(
      group: group,
      mood: mood,
    );

    score += _depthGroupScore(
      group: group,
      depth: depth,
    );

    score += _warmthGroupScore(
      group: group,
      warmth: warmth,
    );

    score += _saturationGroupScore(
      group: group,
      saturation: saturation,
    );

    score += _contrastGroupScore(
      group: group,
      contrast: contrast,
    );

    score += _targetAreaPaletteBonus(
      targetArea: area,
      mood: mood,
      depth: depth,
      warmth: warmth,
      saturation: saturation,
      contrast: contrast,
    );

    return score;
  }

  // ADDED: Look mood group classification
  static String _lookMoodGroup(String look) {
    if (look.contains('emo') ||
        look.contains('e-girl') ||
        look.contains('egirl') ||
        look.contains('smokey') ||
        look.contains('cherry cola') ||
        look.contains('grunge')) {
      return 'dark';
    }

    if (look.contains('k-beauty') ||
        look.contains('k beauty') ||
        look.contains('korean') ||
        look.contains('doll') ||
        look.contains('coquette') ||
        look.contains('strawberry') ||
        look.contains('douyin') ||
        look.contains('cold girl') ||
        look.contains('monochrome pink')) {
      return 'youthful';
    }

    if (look.contains('bronzed') ||
        look.contains('golden') ||
        look.contains('latte') ||
        look.contains('mocha') ||
        look.contains('coffee') ||
        look.contains('old money')) {
      return 'warm';
    }

    if (look.contains('bold') ||
        look.contains('editorial') ||
        look.contains('party') ||
        look.contains('arab') ||
        look.contains('glam')) {
      return 'bold';
    }

    if (look.contains('soft glam') ||
        look.contains('bridal') ||
        look.contains('clean girl') ||
        look.contains('glass skin') ||
        look.contains('natural') ||
        look.contains('no makeup') ||
        look.contains('nude')) {
      return 'soft';
    }

    return 'soft';
  }

  // ADDED: Mood group scoring matrix
  static int _moodGroupScore({
    required String group,
    required String mood,
  }) {
    const matrix = {
      'soft': {
        'soft neutral': 120,
        'rose neutral': 95,
        'warm neutral': 80,
        'pink youthful': 45,
        'brown neutral': 25,
        'bronzed warm': 15,
        'mauve romantic': -30,
        'berry dramatic': -140,
        'dark dramatic': -150,
        'bold editorial': -150,
      },
      'youthful': {
        'pink youthful': 130,
        'rose neutral': 100,
        'soft neutral': 85,
        'mauve romantic': 35,
        'warm neutral': 10,
        'brown neutral': -80,
        'bronzed warm': -70,
        'berry dramatic': -140,
        'dark dramatic': -160,
        'bold editorial': -150,
      },
      'dark': {
        'berry dramatic': 150,
        'dark dramatic': 140,
        'mauve romantic': 110,
        'bold editorial': 60,
        'rose neutral': -40,
        'brown neutral': -50,
        'warm neutral': -110,
        'soft neutral': -150,
        'pink youthful': -160,
        'bronzed warm': -140,
      },
      'warm': {
        'warm neutral': 135,
        'bronzed warm': 130,
        'brown neutral': 110,
        'soft neutral': 65,
        'rose neutral': 40,
        'pink youthful': -60,
        'mauve romantic': -50,
        'berry dramatic': -120,
        'dark dramatic': -130,
        'bold editorial': -70,
      },
      'bold': {
        'bold editorial': 145,
        'berry dramatic': 115,
        'dark dramatic': 110,
        'mauve romantic': 70,
        'bronzed warm': 60,
        'warm neutral': 25,
        'brown neutral': 15,
        'soft neutral': -80,
        'pink youthful': -90,
        'rose neutral': -35,
      },
    };

    return matrix[group]?[mood] ?? -20;
  }

  // ADDED: Depth group scoring
  static int _depthGroupScore({
    required String group,
    required String depth,
  }) {
    switch (group) {
      case 'soft':
        if (depth == 'light') return 45;
        if (depth == 'medium') return 50;
        if (depth == 'deep') return -60;
        break;

      case 'youthful':
        if (depth == 'light') return 65;
        if (depth == 'medium') return 35;
        if (depth == 'deep') return -95;
        break;

      case 'dark':
        if (depth == 'deep') return 70;
        if (depth == 'medium') return 55;
        if (depth == 'light') return -80;
        break;

      case 'warm':
        if (depth == 'medium') return 65;
        if (depth == 'light') return 25;
        if (depth == 'deep') return 20;
        break;

      case 'bold':
        if (depth == 'deep') return 55;
        if (depth == 'medium') return 55;
        if (depth == 'light') return -20;
        break;
    }

    return 0;
  }

  // ADDED: Warmth group scoring
  static int _warmthGroupScore({
    required String group,
    required double warmth,
  }) {
    switch (group) {
      case 'soft':
        if (warmth >= -0.05 && warmth <= 0.35) return 35;
        return -20;

      case 'youthful':
        if (warmth <= 0.25) return 40;
        if (warmth <= 0.40) return 10;
        return -45;

      case 'dark':
        if (warmth <= 0.25) return 45;
        if (warmth <= 0.40) return 10;
        return -40;

      case 'warm':
        if (warmth >= 0.10) return 55;
        return -40;

      case 'bold':
        return 20;
    }

    return 0;
  }

  // ADDED: Saturation group scoring
  static int _saturationGroupScore({
    required String group,
    required double saturation,
  }) {
    switch (group) {
      case 'soft':
        if (saturation <= 0.38) return 45;
        if (saturation <= 0.52) return 20;
        return -50;

      case 'youthful':
        if (saturation <= 0.48) return 45;
        if (saturation <= 0.62) return 15;
        return -55;

      case 'dark':
        if (saturation >= 0.22) return 45;
        return -35;

      case 'warm':
        if (saturation <= 0.55) return 40;
        return -25;

      case 'bold':
        if (saturation >= 0.28) return 55;
        return -30;
    }

    return 0;
  }

  // ADDED: Contrast group scoring
  static int _contrastGroupScore({
    required String group,
    required double contrast,
  }) {
    switch (group) {
      case 'soft':
        if (contrast <= 0.58) return 45;
        if (contrast <= 0.68) return 10;
        return -60;

      case 'youthful':
        if (contrast <= 0.52) return 60;
        if (contrast <= 0.62) return 15;
        return -70;

      case 'dark':
        if (contrast >= 0.45) return 65;
        if (contrast >= 0.35) return 25;
        return -50;

      case 'warm':
        if (contrast <= 0.70) return 35;
        return -20;

      case 'bold':
        if (contrast >= 0.45) return 55;
        return -20;
    }

    return 0;
  }

  // ADDED: Target area palette bonus
  static int _targetAreaPaletteBonus({
    required String targetArea,
    required String mood,
    required String depth,
    required double warmth,
    required double saturation,
    required double contrast,
  }) {
    var score = 0;

    if (targetArea.contains('contour')) {
      if (mood == 'warm neutral' ||
          mood == 'brown neutral' ||
          mood == 'bronzed warm' ||
          mood == 'soft neutral') {
        score += 45;
      }

      if (mood == 'berry dramatic' ||
          mood == 'pink youthful' ||
          mood == 'bold editorial') {
        score -= 80;
      }

      if (warmth >= 0.05 && saturation <= 0.45) {
        score += 25;
      }
    }

    if (targetArea.contains('eye') || targetArea.contains('shadow')) {
      if (mood == 'berry dramatic' ||
          mood == 'mauve romantic' ||
          mood == 'soft neutral' ||
          mood == 'warm neutral' ||
          mood == 'pink youthful' ||
          mood == 'bold editorial') {
        score += 35;
      }

      if (depth == 'deep' && contrast >= 0.45) {
        score += 15;
      }
    }

    return score;
  }

  static String _moodFromPalette({
    required List<String> families,
    required double warmth,
    required double saturation,
    required double contrast,
    required String depth,
  }) {
    final berryCount = _countFamilies(
      families,
      ['berry', 'plum', 'wine', 'mauve'],
    );

    final pinkCount = _countFamilies(
      families,
      ['pink', 'rose'],
    );

    final brownCount = _countFamilies(
      families,
      ['brown', 'nude', 'beige', 'caramel', 'taupe'],
    );

    final peachCount = _countFamilies(
      families,
      ['peach', 'coral', 'terracotta'],
    );

    final darkCount = _countFamilies(
      families,
      ['deep', 'dark', 'espresso'],
    );

    final neutralCount = brownCount + peachCount;

    // STRICT RULE 1:
    // Berry-heavy palettes must never be classified as soft neutral.
    if (berryCount >= 3 && contrast >= 0.50) {
      return 'berry dramatic';
    }

    if (berryCount >= 2 && darkCount >= 1) {
      return 'berry dramatic';
    }

    if (berryCount >= 2 && neutralCount <= 2) {
      return 'mauve romantic';
    }

    if (berryCount >= 2 && pinkCount >= 2) {
      return 'mauve romantic';
    }

    // STRICT RULE 2:
    // Deep palettes with berry/plum identity become dramatic.
    if (darkCount >= 2 && berryCount >= 1 && contrast >= 0.45) {
      return 'dark dramatic';
    }

    // STRICT RULE 3:
    // Editorial should not trigger from contrast alone.
    if (contrast >= 0.72 &&
        saturation >= 0.42 &&
        darkCount >= 2 &&
        neutralCount <= 1) {
      return 'bold editorial';
    }

    // STRICT RULE 4:
    // Pink youthful palettes are light, low contrast, low saturation.
    if (pinkCount >= 2 &&
        berryCount <= 1 &&
        contrast <= 0.52 &&
        saturation <= 0.42 &&
        depth != 'deep') {
      return 'pink youthful';
    }

    // STRICT RULE 5:
    // Warm palettes with brown/peach base.
    if (peachCount >= 2 && warmth >= 0.12 && berryCount == 0) {
      return 'bronzed warm';
    }

    if (brownCount >= 3 && warmth >= 0.12 && depth != 'deep') {
      return 'warm neutral';
    }

    if (brownCount >= 3) {
      return 'brown neutral';
    }

    if (pinkCount >= 1 && brownCount >= 1 && berryCount <= 1) {
      return 'rose neutral';
    }

    return 'soft neutral';
  }

  static _ColorSignals _signals(Color color) {
    final r = color.red;
    final g = color.green;
    final b = color.blue;

    final maxChannel = max(r, max(g, b));
    final minChannel = min(r, min(g, b));

    final brightness =
        ((0.299 * r) + (0.587 * g) + (0.114 * b)) / 255.0;

    final saturation = (maxChannel - minChannel) / 255.0;

    final warmth = ((r - b) / 255.0).clamp(-1.0, 1.0);

    return _ColorSignals(
      brightness: brightness,
      saturation: saturation,
      warmth: warmth,
    );
  }

  static String _familyFromColor(Color color) {
    final r = color.red;
    final g = color.green;
    final b = color.blue;

    final brightness =
        ((0.299 * r) + (0.587 * g) + (0.114 * b));

    final maxChannel = max(r, max(g, b));
    final minChannel = min(r, min(g, b));
    final saturation = maxChannel - minChannel;

    // Deep shades first.
    if (brightness < 70) {
      if (r > 80 && b > 60) return 'Deep Plum';
      if (r > 75 && g < 65 && b < 65) return 'Wine Berry';
      if (r > 70 && g > 45 && b < 55) return 'Espresso Brown';
      return 'Deep Brown';
    }

    // Wine / berry / plum detection.
    if (r >= 120 && b >= 80 && g <= 115) {
      if (brightness < 115) return 'Wine Berry';
      if (b > r - 10) return 'Cool Berry';
      return 'Berry Pink';
    }

    if (r >= 145 && b >= 95 && g <= 135) {
      if (brightness < 130) return 'Wine Berry';
      if (saturation < 55) return 'Dusty Mauve';
      return 'Berry Pink';
    }

    if (r >= 150 && b >= 115 && g <= 155) {
      if (saturation < 60) return 'Dusty Mauve';
      return 'Rosy Pink';
    }

    // Soft pink / rose.
    if (r >= 180 && b >= 145 && g >= 135) {
      if (saturation < 45) return 'Soft Rose';
      return 'Soft Pink';
    }

    // Peach / coral / terracotta.
    if (r >= 180 && g >= 120 && b <= 145) {
      if (g >= 145 && b >= 115) return 'Soft Peach';
      if (g >= 120 && b < 110) return 'Warm Coral';
      return 'Terracotta';
    }

    // Brown / nude / beige.
    if (r >= 150 && g >= 120 && b >= 95) {
      if (brightness > 205) return 'Beige Nude';
      if ((r - g).abs() < 35 && (g - b).abs() < 40) return 'Taupe Nude';
      return 'Caramel Nude';
    }

    if (r >= 115 && g >= 85 && b >= 60) {
      if (r - b > 35) return 'Warm Brown';
      return 'Brown Nude';
    }

    if (r >= 90 && g >= 65 && b >= 50) {
      return 'Deep Brown';
    }

    return 'Soft Neutral';
  }

  static int _countFamilies(List<String> families, List<String> keywords) {
    var count = 0;

    for (final family in families) {
      final f = family.toLowerCase();

      for (final keyword in keywords) {
        if (f.contains(keyword)) {
          count++;
          break;
        }
      }
    }

    return count;
  }

  static String _depthFromBrightness(double brightness) {
    if (brightness >= 0.72) return 'light';
    if (brightness >= 0.38) return 'medium';
    return 'deep';
  }

  static Color? _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();

    if (cleaned.length != 6) return null;

    try {
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return null;
    }
  }

  static double _avg(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

class _ColorSignals {
  final double brightness;
  final double saturation;
  final double warmth;

  const _ColorSignals({
    required this.brightness,
    required this.saturation,
    required this.warmth,
  });
}
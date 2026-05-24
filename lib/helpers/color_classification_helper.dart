import 'package:flutter/material.dart';

class DetectedColorProfile {
  final String colorFamily;
  final List<String> undertones;
  final String shadeDepth;

  const DetectedColorProfile({
    required this.colorFamily,
    required this.undertones,
    required this.shadeDepth,
  });
}

class ColorClassificationHelper {
  static DetectedColorProfile classify(String hex) {
    final color = _fromHex(hex);

    if (color == null) {
      return const DetectedColorProfile(
        colorFamily: 'Unknown',
        undertones: ['Neutral'],
        shadeDepth: 'Medium',
      );
    }

    final hsl = HSLColor.fromColor(color);
    final hue = hsl.hue;
    final sat = hsl.saturation;
    final light = hsl.lightness;

    return DetectedColorProfile(
      colorFamily: _family(hue, sat, light),
      undertones: _undertones(hue, sat, light),
      shadeDepth: _depth(light),
    );
  }

  static Color? _fromHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(cleaned)) return null;
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  static String _depth(double light) {
    if (light >= 0.82) return 'Fair';
    if (light >= 0.68) return 'Light';
    if (light >= 0.48) return 'Medium';
    if (light >= 0.30) return 'Morena';
    return 'Deep Morena';
  }

  static List<String> _undertones(double hue, double sat, double light) {
    final tones = <String>{};

    if (hue >= 10 && hue <= 65) tones.add('Warm');
    if (hue >= 285 || hue <= 10) tones.add('Cool');
    if (sat < 0.35 || light > 0.70) tones.add('Neutral');

    if (tones.isEmpty) tones.add('Neutral');

    return tones.toList();
  }

  static String _family(double hue, double sat, double light) {
    if (light < 0.22) {
      if (hue >= 330 || hue <= 15) return 'Black Cherry';
      if (hue >= 270 && hue < 330) return 'Deep Plum';
      if (hue >= 15 && hue <= 55) return 'Warm Brown';
      return 'Smokey Brown';
    }

    if (hue >= 345 || hue <= 8) {
      if (light < 0.42) return 'Wine Red';
      if (sat > 0.55) return 'Cherry Red';
      return 'Muted Rose';
    }

    if (hue > 8 && hue <= 22) {
      if (light < 0.45) return 'Terracotta';
      if (sat > 0.50) return 'Warm Coral';
      return 'Peach Nude';
    }

    if (hue > 22 && hue <= 45) {
      if (light < 0.40) return 'Warm Brown';
      if (sat > 0.45) return 'Terracotta';
      return 'Brown Nude';
    }

    if (hue > 45 && hue <= 70) {
      return light > 0.65 ? 'Champagne' : 'Golden Brown';
    }

    if (hue >= 285 && hue < 330) {
      if (light < 0.40) return 'Plum';
      if (sat < 0.38) return 'Dusty Mauve';
      return 'Berry Pink';
    }

    if (hue >= 330 && hue < 345) {
      if (light < 0.42) return 'Dark Berry';
      if (sat < 0.35) return 'Muted Rose';
      if (light > 0.68) return 'Soft Pink';
      return 'Berry Pink';
    }

    if (sat < 0.25) return 'Muted Rose';

    return 'Rosy Pink';
  }
}
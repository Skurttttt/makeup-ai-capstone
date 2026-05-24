import 'package:flutter/material.dart';

class ColorCalibrationHelper {
  static Color calibrateLipColor(Color color) {
    final hsl = HSLColor.fromColor(color);

    return hsl
        .withSaturation(
          (hsl.saturation * 1.10).clamp(0.0, 1.0),
        )
        .withLightness(
          (hsl.lightness * 0.88).clamp(0.0, 1.0),
        )
        .toColor();
  }
}
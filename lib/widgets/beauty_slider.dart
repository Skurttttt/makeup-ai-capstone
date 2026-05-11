import 'package:flutter/material.dart';

class BeautySlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const BeautySlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFFF4D97);

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: pink,
        inactiveTrackColor: const Color(0xFFFFD9E9),
        thumbColor: Colors.white,
        overlayColor: pink.withOpacity(0.12),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 13,
          elevation: 4,
          pressedElevation: 6,
        ),
        overlayShape: const RoundSliderOverlayShape(
          overlayRadius: 22,
        ),
      ),
      child: Slider(
        value: value,
        min: 0,
        max: 1,
        divisions: 20,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}
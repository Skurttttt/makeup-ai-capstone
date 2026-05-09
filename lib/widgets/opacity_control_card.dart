import 'package:flutter/material.dart';
import 'beauty_slider.dart';

class OpacityControlCard extends StatelessWidget {
  final ValueNotifier<double> globalOpacity;
  final ValueChanged<double> onApplyGlobal;

  const OpacityControlCard({
    super.key,
    required this.globalOpacity,
    required this.onApplyGlobal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD9E9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D97).withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: globalOpacity,
        builder: (context, value, _) {
          return Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Global Opacity',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(value * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF4D97),
                    ),
                  ),
                ],
              ),
              BeautySlider(
                value: value,
                onChanged: (v) => globalOpacity.value = v,
                onChangeEnd: onApplyGlobal,
              ),
            ],
          );
        },
      ),
    );
  }
}
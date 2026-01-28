import 'package:flutter/material.dart';
import 'look_engine.dart';

class LookPicker extends StatelessWidget {
  final MakeupLookPreset value;
  final ValueChanged<MakeupLookPreset> onChanged;

  const LookPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final looks = const [
      MakeupLookPreset.softGlam,
      MakeupLookPreset.dollKBeauty,
      MakeupLookPreset.bronzedGoddess,
      MakeupLookPreset.emo,
      MakeupLookPreset.boldEditorial,
      MakeupLookPreset.debugPainterTest, // 🔧 keep visible
    ];

    return DropdownButtonFormField<MakeupLookPreset>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Select Makeup Look',
        border: OutlineInputBorder(),
      ),
      items: looks
          .map(
            (p) => DropdownMenuItem(
              value: p,
              child: Text(p.label), // ✅ reuse label extension
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

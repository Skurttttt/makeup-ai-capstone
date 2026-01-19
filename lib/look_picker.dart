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
    // A) Add it to the dropdown list
    final looks = [
      MakeupLookPreset.noMakeup,
      MakeupLookPreset.everydayFresh,
      MakeupLookPreset.officeProfessional,
      MakeupLookPreset.cleanGirl,
      MakeupLookPreset.emo,
      MakeupLookPreset.debugPainterTest, // 🔧 TEMPORARY - Added debug preset
    ];

    // B) Add a visible label helper function
    String labelFor(MakeupLookPreset preset) {
      switch (preset) {
        case MakeupLookPreset.noMakeup:
          return 'No-Makeup Look';
        case MakeupLookPreset.everydayFresh:
          return 'Everyday Fresh';
        case MakeupLookPreset.officeProfessional:
          return 'Office / Professional';
        case MakeupLookPreset.cleanGirl:
          return 'Clean Girl';
        case MakeupLookPreset.emo:
          return 'Emo Look';
        case MakeupLookPreset.debugPainterTest:
          return '🔧 Debug – Painter Test'; // ⚠️ VERY OBVIOUS
      }
    }

    return DropdownButtonFormField<MakeupLookPreset>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Select Makeup Look',
        border: OutlineInputBorder(),
      ),
      items: looks
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text(labelFor(p)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
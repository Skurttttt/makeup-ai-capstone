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
    final looks = [
      (MakeupLookPreset.softGlam, 'Soft Glam', Icons.face),
      (MakeupLookPreset.emo, 'Emo', Icons.nightlife),
      (MakeupLookPreset.dollKBeauty, 'Doll K-Beauty', Icons.local_florist),
      (MakeupLookPreset.bronzedGoddess, 'Bronzed Goddess', Icons.sunny),
      (MakeupLookPreset.boldEditorial, 'Bold Editorial', Icons.brightness_3),
    ];

    return DropdownButtonFormField<MakeupLookPreset>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Choose Your Look',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.palette, color: Color(0xFFFF4D97)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: looks.map((item) {
        final preset = item.$1;
        final label = item.$2;
        final icon = item.$3;

        return DropdownMenuItem<MakeupLookPreset>(
          value: preset,
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFFFF4D97)),
              const SizedBox(width: 12),
              Text(label),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

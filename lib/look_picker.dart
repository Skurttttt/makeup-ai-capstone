import 'package:flutter/material.dart';
import 'look_engine.dart';

class LookPicker extends StatelessWidget {
  final MakeupLookPreset value;
  final ValueChanged<MakeupLookPreset> onChanged;

  const LookPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final looks = [
      (MakeupLookPreset.softGlam, 'Soft Glam', Icons.face),
      (MakeupLookPreset.dollKBeauty, 'K-Beauty', Icons.local_florist),
      (MakeupLookPreset.emo, 'Emo', Icons.nightlife),
      (MakeupLookPreset.bronzedGoddess, 'Bronzed Goddess', Icons.sunny),
      (MakeupLookPreset.boldEditorial, 'Bold Editorial', Icons.brightness_3),

      (MakeupLookPreset.cleanGirl, 'Clean Girl', Icons.spa),
      (MakeupLookPreset.coquette, 'Coquette', Icons.favorite_border),
      (MakeupLookPreset.strawberryMakeup, 'Strawberry Makeup', Icons.local_cafe),
      (MakeupLookPreset.peachGirl, 'Peach Girl', Icons.wb_sunny_outlined),
      (MakeupLookPreset.glassSkin, 'Glass Skin', Icons.water_drop_outlined),
      (MakeupLookPreset.naturalNude, 'Natural Nude', Icons.palette_outlined),
      (MakeupLookPreset.noMakeupMakeup, 'No Makeup Makeup', Icons.blur_on),
      (MakeupLookPreset.oldMoney, 'Old Money', Icons.diamond_outlined),
      (MakeupLookPreset.goldenGoddess, 'Golden Goddess', Icons.auto_awesome),
      (MakeupLookPreset.arabGlam, 'Arab Glam', Icons.visibility_outlined),
      (MakeupLookPreset.bridalGlam, 'Bridal Glam', Icons.celebration_outlined),
      (MakeupLookPreset.victoriaSecretGlam, 'Victoria Secret Glam', Icons.favorite),
      (MakeupLookPreset.partyGlam, 'Party Glam', Icons.star_border),
      (MakeupLookPreset.douyin, 'Douyin', Icons.camera_alt_outlined),
      (MakeupLookPreset.latteMakeup, 'Latte Makeup', Icons.coffee),
      (MakeupLookPreset.cherryCola, 'Cherry Cola', Icons.local_drink_outlined),
      (MakeupLookPreset.coldGirlMakeup, 'Cold Girl Makeup', Icons.ac_unit),
      (MakeupLookPreset.monochromePink, 'Monochrome Pink', Icons.color_lens_outlined),
      (MakeupLookPreset.eGirl, 'E-Girl', Icons.bolt),
      (MakeupLookPreset.smokeyEyes, 'Smokey Eyes', Icons.dark_mode_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<MakeupLookPreset>(
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
        ),
      ],
    );
  }
}
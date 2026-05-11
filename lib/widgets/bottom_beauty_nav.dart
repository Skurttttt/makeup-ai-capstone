import 'package:flutter/material.dart';

class BottomBeautyNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomBeautyNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const selectedBg = Color(0xFFFFE6F1);
    const activeColor = Color(0xFF20171D);
    const inactiveColor = Color(0xFF5A4F56);

    final items = const [
      _BeautyNavItem(Icons.home_outlined, 'Home'),
      _BeautyNavItem(Icons.face_retouching_natural_outlined, 'Scan'),
      _BeautyNavItem(Icons.shopping_bag_outlined, 'Market'),
      _BeautyNavItem(Icons.workspace_premium_outlined, 'Premium'),
      _BeautyNavItem(Icons.settings_outlined, 'Settings'),
    ];

    return Container(
      height: 68, // Reduced from 88
      width: double.infinity,
      // Removed padding completely
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFF3EEF1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final selected = index == currentIndex;

          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 32, // Reduced from 38
                    width: 64, // Reduced from 78
                    decoration: BoxDecoration(
                      color: selected ? selectedBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      item.icon,
                      size: 24, // Reduced from 28
                      color: selected ? activeColor : inactiveColor,
                    ),
                  ),
                  const SizedBox(height: 2), // Reduced from 4
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12, // Reduced from 14
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BeautyNavItem {
  final IconData icon;
  final String label;

  const _BeautyNavItem(this.icon, this.label);
}
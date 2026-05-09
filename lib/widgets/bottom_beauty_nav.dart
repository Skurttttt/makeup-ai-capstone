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
    const pink = Color(0xFFFF4D97);
    const inactive = Color(0xFF8E8E93);

    final items = const [
      _BeautyNavItem(Icons.home_outlined, Icons.home, 'Home'),
      _BeautyNavItem(
        Icons.face_retouching_natural_outlined,
        Icons.face_retouching_natural,
        'Scan',
      ),
      _BeautyNavItem(
        Icons.shopping_bag_outlined,
        Icons.shopping_bag,
        'Market',
      ),
      _BeautyNavItem(
        Icons.card_membership_outlined,
        Icons.card_membership,
        'Premium',
      ),
      _BeautyNavItem(
        Icons.settings_outlined,
        Icons.settings,
        'Settings',
      ),
    ];

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.black.withOpacity(0.06),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final selected = index == currentIndex;

          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 23,
                    color: selected ? pink : inactive,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? pink : inactive,
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
  final IconData activeIcon;
  final String label;

  const _BeautyNavItem(this.icon, this.activeIcon, this.label);
}
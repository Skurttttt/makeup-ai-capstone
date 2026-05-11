import 'package:flutter/material.dart';

class BottomActionButtons extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onTutorial;
  final VoidCallback onBuyProducts;

  const BottomActionButtons({
    super.key,
    required this.onBack,
    required this.onTutorial,
    required this.onBuyProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                isPrimary: false,
                onTap: onBack,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                label: 'Tutorial',
                icon: Icons.school_rounded,
                isPrimary: true,
                onTap: onTutorial,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ActionButton(
          label: 'Buy Products',
          icon: Icons.shopping_bag_outlined,
          isPrimary: true,
          isWide: true,
          onTap: onBuyProducts,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final bool isWide;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    this.isWide = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFFF4D97);

    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: SizedBox(
        height: isWide ? 52 : 50,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 21),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: isPrimary ? pink : Colors.white,
            foregroundColor: isPrimary ? Colors.white : pink,
            textStyle: TextStyle(
              fontSize: isWide ? 17 : 16,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: pink, width: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}
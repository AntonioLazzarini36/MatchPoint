import 'package:flutter/material.dart';

class DiscoverySwipeActionBg extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final Color color;

  const DiscoverySwipeActionBg({
    super.key,
    required this.alignment,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: const Icon(
          Icons.circle,
          color: Colors.white,
          size: 0,
        ), // placeholder to keep size
      ),
    );
  }
}

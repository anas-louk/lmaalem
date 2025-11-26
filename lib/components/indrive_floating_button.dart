import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Bouton flottant moderne avec style InDrive
class InDriveFloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;

  const InDriveFloatingButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = backgroundColor ?? AppColors.secondary;
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip,
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(icon, size: 24),
      ),
    );
  }
}


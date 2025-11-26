import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Carte moderne inspirée d'InDrive avec thème sombre
class InDriveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final GestureTapCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;
  final double elevation;
  final bool showShadow;

  const InDriveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.backgroundColor,
    this.borderRadius = 24,
    this.elevation = 0,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = backgroundColor ?? AppColors.nightSurface;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white10,
          width: 1,
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                if (elevation > 0)
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          splashColor: AppColors.primary.withOpacity(0.1),
          highlightColor: AppColors.primary.withOpacity(0.05),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:physical_therapy/core/constants/app_colors.dart';

/// Shared card widget with a subtle physical top-left to bottom-right
/// linear gradient background, matching the theme's Card border and radius.
class GradientCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  /// Override border color (uses AppColors border by default).
  final Color? borderColor;
  /// Override border width (uses 1.0 by default).
  final double? borderWidth;

  const GradientCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderColor,
    this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final secondary = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
    final defaultBorderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final endColor = Color.alphaBlend(
      secondary.withValues(alpha: 0.20),
      surface,
    );

    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    return Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surface, endColor],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? defaultBorderColor,
          width: borderWidth ?? 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: content,
              )
            : content,
      ),
    );
  }
}

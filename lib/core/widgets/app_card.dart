import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderRadius = 16,
    this.elevation = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final card = Card(
      elevation: elevation,
      margin: margin ?? EdgeInsets.zero,
      color: backgroundColor ?? colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    final animatedCard = card
        .animate()
        .fadeIn(duration: 180.ms, curve: Curves.easeOut)
        .slideY(begin: 0.03, end: 0, duration: 220.ms, curve: Curves.easeOut);

    if (onTap == null) return animatedCard;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: animatedCard,
    );
  }
}

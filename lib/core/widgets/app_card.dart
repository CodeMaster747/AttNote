import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Flat, bordered container used as the primary grouping primitive.
///
/// No drop shadows — depth comes from a subtle border + an optional muted
/// background. Tap state is a soft background shift, not a scale.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = AppRadius.lg,
    this.interactive = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool interactive;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bg = widget.backgroundColor ?? colors.surface;
    final border = widget.borderColor ?? colors.border;
    final radius = BorderRadius.circular(widget.borderRadius);
    final hoverable = widget.onTap != null && widget.interactive;

    final container = AnimatedContainer(
      duration: AppDuration.base,
      curve: Curves.easeOut,
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: hoverable && _hovered ? colors.surfaceMuted : bg,
        borderRadius: radius,
        border: Border.all(color: border, width: 1),
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return container;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: container,
      ),
    );
  }
}

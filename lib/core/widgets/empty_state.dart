import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../theme/app_spacing.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
    this.padding = AppSpacing.pagePadding,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colorScheme.primary),
            const Gap(AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const Gap(AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

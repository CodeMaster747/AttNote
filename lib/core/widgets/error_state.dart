import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../theme/app_spacing.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline_rounded,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.padding = AppSpacing.pagePadding,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;
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
            Icon(icon, size: 56, color: colorScheme.error),
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
            if (onRetry != null) ...[
              const Gap(AppSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

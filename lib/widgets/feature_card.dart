import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const FeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.accentColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color effectiveAccent = accentColor ?? colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: effectiveAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: effectiveAccent.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: effectiveAccent, size: 22),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

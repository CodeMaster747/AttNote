import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_spacing.dart';

class AppShimmer extends StatelessWidget {
  const AppShimmer({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      highlightColor: colorScheme.surface,
      child: child,
    );
  }
}

class ShimmerLine extends StatelessWidget {
  const ShimmerLine({
    super.key,
    this.height = 12,
    this.width = double.infinity,
    this.radius = 8,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ShimmerCardList extends StatelessWidget {
  const ShimmerCardList({
    super.key,
    this.itemCount = 4,
    this.padding = AppSpacing.pagePadding,
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const Gap(AppSpacing.md),
      itemBuilder: (_, __) => const _ShimmerCardItem(),
    );
  }
}

class _ShimmerCardItem extends StatelessWidget {
  const _ShimmerCardItem();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLine(height: 16, width: 180),
          Gap(AppSpacing.sm),
          ShimmerLine(height: 12),
          Gap(AppSpacing.xs),
          ShimmerLine(height: 12, width: 220),
        ],
      ),
    );
  }
}

class ShimmerCircleAvatar extends StatelessWidget {
  const ShimmerCircleAvatar({
    super.key,
    this.size = 44,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Quiet page backdrop. Renders a single, near-flat surface — the previous
/// gradient blobs were swapped for a thin top-edge gradient that's almost
/// imperceptible but adds calm depth without decoration.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.surfaceMuted.withValues(alpha: 0.35),
              colors.background,
            ],
            stops: const [0.0, 0.32],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

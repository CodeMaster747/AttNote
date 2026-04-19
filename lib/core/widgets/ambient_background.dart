import 'package:flutter/material.dart';

/// Subtle mesh-style background for a more premium look.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.tertiary.withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

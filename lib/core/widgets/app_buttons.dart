import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Primary filled button — the single saturated affordance on a screen.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? _LoadingChild(label: label, color: Theme.of(context).colorScheme.onPrimary)
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              )
            : Text(label);

    return _PressFeedback(
      enabled: onPressed != null && !isLoading,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
    );
  }
}

/// Secondary outlined button — neutral, low-emphasis.
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(label),
            ],
          )
        : Text(label);
    return _PressFeedback(
      enabled: onPressed != null,
      child: OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}

/// Plain text affordance.
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(label),
            ],
          )
        : Text(label);
    return _PressFeedback(
      enabled: onPressed != null,
      child: TextButton(onPressed: onPressed, child: child),
    );
  }
}

class _LoadingChild extends StatelessWidget {
  const _LoadingChild({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

/// Subtle press feedback — opacity tweak instead of scale, keeps the
/// interaction calm and SaaS-grade.
class _PressFeedback extends StatefulWidget {
  const _PressFeedback({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<_PressFeedback> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final opacity = widget.enabled && _pressed ? 0.85 : 1.0;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: AppDuration.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

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
    final buttonChild = isLoading
        ? _ButtonLoadingContent(label: label)
        : Text(label);

    final button = icon != null && !isLoading
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: buttonChild,
          )
        : FilledButton(
            onPressed: onPressed,
            child: buttonChild,
          );

    return _ScaleOnPress(
      enabled: onPressed != null && !isLoading,
      child: button,
    );
  }
}

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
    final button = icon != null
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            child: Text(label),
          );
    return _ScaleOnPress(
      enabled: onPressed != null,
      child: button,
    );
  }
}

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
    final button = icon != null
        ? TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : TextButton(
            onPressed: onPressed,
            child: Text(label),
          );
    return _ScaleOnPress(
      enabled: onPressed != null,
      child: button,
    );
  }
}

class _ButtonLoadingContent extends StatelessWidget {
  const _ButtonLoadingContent({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpinKitThreeBounce(
          color: color,
          size: 14,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _ScaleOnPress extends StatefulWidget {
  const _ScaleOnPress({
    required this.child,
    required this.enabled,
  });

  final Widget child;
  final bool enabled;

  @override
  State<_ScaleOnPress> createState() => _ScaleOnPressState();
}

class _ScaleOnPressState extends State<_ScaleOnPress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = widget.enabled && _pressed ? 0.985 : 1.0;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

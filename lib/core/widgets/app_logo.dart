import 'package:flutter/material.dart';

/// Brand mark used in app bars, landing pages, splash screens, etc.
///
/// The asset is a transparent-background glyph designed to sit directly on
/// any surface — no extra framing required.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 28});

  /// Edge length of the logo tile in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/AttNote_Inside_App.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

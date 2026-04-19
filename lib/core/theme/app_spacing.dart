import 'package:flutter/widgets.dart';

/// Global 8pt spacing tokens for consistent layout rhythm.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;

  static const EdgeInsets pagePadding = EdgeInsets.all(md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: xs,
  );
}

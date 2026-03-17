import 'package:flutter/material.dart';

/// Design tokens for the Trulana dark UI.
///
/// Kept as an abstract class with static constants so it can never be
/// instantiated — it exists purely as a compile-time colour namespace.
abstract class TrulanaColors {
  TrulanaColors._();

  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceLight = Color(0xFF1A1A2E);

  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color dangerRed = Color(0xFFFF1744);
  static const Color successGreen = Color(0xFF00E676);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x61FFFFFF);

  static const Color glassBorder = Color(0x1FFFFFFF);
  static const Color glassFill = Color(0x0FFFFFFF);
}

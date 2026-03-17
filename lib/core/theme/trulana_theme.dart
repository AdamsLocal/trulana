import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'trulana_colors.dart';

/// Centralised Material 3 theme built on [TrulanaColors].
///
/// A single static getter keeps the widget tree clean (`TrulanaTheme.darkTheme`)
/// while still giving us a strongly-typed, testable theme object.
class TrulanaTheme {
  TrulanaTheme._();

  static ThemeData get darkTheme {
    final ThemeData base = ThemeData.dark();

    final TextTheme baseText = GoogleFonts.interTextTheme(base.textTheme);

    final TextTheme textTheme = baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: TrulanaColors.textPrimary,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: TrulanaColors.textSecondary,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: TrulanaColors.textSecondary,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: TrulanaColors.textTertiary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: TrulanaColors.background,
      colorScheme: const ColorScheme.dark(
        surface: TrulanaColors.surface,
        primary: TrulanaColors.primaryCyan,
        error: TrulanaColors.dangerRed,
        onPrimary: TrulanaColors.background,
        onSurface: TrulanaColors.textPrimary,
        onError: TrulanaColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: TrulanaColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: TrulanaColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: TrulanaColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TrulanaColors.glassBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TrulanaColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TrulanaColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TrulanaColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: TrulanaColors.primaryCyan,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TrulanaColors.dangerRed),
        ),
        hintStyle: const TextStyle(color: TrulanaColors.textTertiary),
        labelStyle: const TextStyle(color: TrulanaColors.textSecondary),
      ),
    );
  }

  /// Monospaced style for numeric/metric displays (balances, IDs, hashes).
  static TextStyle get monoStyle => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: TrulanaColors.textPrimary,
      );
}

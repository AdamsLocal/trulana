import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'sovereign_colors.dart';

/// Centralised Material 3 theme built on [SovereignColors].
///
/// A single static getter keeps the widget tree clean (`SovereignTheme.darkTheme`)
/// while still giving us a strongly-typed, testable theme object.
class SovereignTheme {
  SovereignTheme._();

  static ThemeData get darkTheme {
    final ThemeData base = ThemeData.dark();

    final TextTheme baseText = GoogleFonts.interTextTheme(base.textTheme);

    final TextTheme textTheme = baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: SovereignColors.textPrimary,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: SovereignColors.textSecondary,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: SovereignColors.textSecondary,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: SovereignColors.textTertiary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: SovereignColors.background,
      colorScheme: const ColorScheme.dark(
        surface: SovereignColors.surface,
        primary: SovereignColors.primaryCyan,
        error: SovereignColors.dangerRed,
        onPrimary: SovereignColors.background,
        onSurface: SovereignColors.textPrimary,
        onError: SovereignColors.textPrimary,
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
          color: SovereignColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: SovereignColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: SovereignColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SovereignColors.glassBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SovereignColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SovereignColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SovereignColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: SovereignColors.primaryCyan,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SovereignColors.dangerRed),
        ),
        hintStyle: const TextStyle(color: SovereignColors.textTertiary),
        labelStyle: const TextStyle(color: SovereignColors.textSecondary),
      ),
    );
  }

  /// Monospaced style for numeric/metric displays (balances, IDs, hashes).
  static TextStyle get monoStyle => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: SovereignColors.textPrimary,
      );
}

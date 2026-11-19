import 'package:flutter/material.dart';

import 'bouga_tokens.dart';

abstract final class BougaTheme {
  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: BougaColors.mint,
      secondary: BougaColors.gold,
      surface: BougaColors.surface,
      error: BougaColors.danger,
      onPrimary: BougaColors.background,
      onSurface: BougaColors.text,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: BougaColors.background,
      fontFamily: 'Tajawal',
      appBarTheme: const AppBarTheme(
        backgroundColor: BougaColors.background,
        foregroundColor: BougaColors.text,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: BougaColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BougaRadii.card),
          side: const BorderSide(color: BougaColors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BougaColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BougaRadii.control),
          borderSide: const BorderSide(color: BougaColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BougaRadii.control),
          borderSide: const BorderSide(color: BougaColors.outline),
        ),
      ),
    );
  }
}

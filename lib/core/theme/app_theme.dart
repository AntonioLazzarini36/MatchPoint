import 'package:flutter/material.dart';
import 'app_buttons.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(useMaterial3: true, brightness: Brightness.light);
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final cs = base.colorScheme;

    return base.copyWith(
      filledButtonTheme: AppButtons.filled(cs),
      outlinedButtonTheme: AppButtons.outlined(cs),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: const TextStyle(fontSize: 18),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/app/theme/app_button_styles.dart';
import 'package:attendance_kiosk_app/app/theme/app_colors.dart';

/// Material 3 enterprise theme with brand primary [#1C6ADC].
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
    );

    final typography = Typography.material2021(platform: TargetPlatform.iOS);
    final baseTextTheme = (brightness == Brightness.light ? typography.black : typography.white)
        .apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    final textTheme = baseTextTheme.copyWith(
      labelLarge: AppButtonStyles.label,
      labelMedium: AppButtonStyles.labelCompact,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF0F4FA)
          : const Color(0xFF0E1520),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: AppButtonStyles.filledStyle().copyWith(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppButtonStyles.outlinedStyle(),
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppButtonStyles.textStyleButton(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppButtonStyles.filledStyle(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

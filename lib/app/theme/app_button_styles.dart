import 'package:flutter/material.dart';

/// Shared label styling for all Material buttons in the app.
abstract final class AppButtonStyles {
  /// Primary actions: Login, Register, Check-in, Face config, etc.
  static const TextStyle label = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.15,
  );

  /// Compact actions on dense cards (e.g. employee roster).
  static const TextStyle labelCompact = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.1,
  );

  static ButtonStyle filledStyle({TextStyle? textStyle}) {
    return FilledButton.styleFrom(textStyle: textStyle ?? label);
  }

  static ButtonStyle outlinedStyle({TextStyle? textStyle}) {
    return OutlinedButton.styleFrom(textStyle: textStyle ?? label);
  }

  static ButtonStyle textStyleButton({TextStyle? textStyle}) {
    return TextButton.styleFrom(textStyle: textStyle ?? label);
  }
}

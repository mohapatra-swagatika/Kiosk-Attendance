import 'package:flutter/material.dart';

/// Brand and gradient tokens for the kiosk app.
abstract final class AppColors {
  static const Color primary = Color(0xFF1C6ADC);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1C6ADC),
      Color(0xFF3D8AE8),
      Color(0xFF5BA3F5),
    ],
  );

  static const LinearGradient primaryGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D3A7A),
      Color(0xFF1C6ADC),
      Color(0xFF2A5FBD),
    ],
  );

  static LinearGradient scaffoldGradient(Brightness brightness) {
    return brightness == Brightness.light
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F0FC), Color(0xFFF4F7FB), Color(0xFFFFFFFF)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF121C2E), Color(0xFF1A2438)],
          );
  }
}

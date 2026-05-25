import 'package:flutter/foundation.dart';

import 'package:attendance_kiosk_app/core/config/app_environment.dart';

/// Application configuration resolved at compile time via `--dart-define`.
///
/// Examples:
/// - `flutter run --dart-define=APP_ENV=staging`
/// - `flutter run --dart-define=VERBOSE_LOGS=true`
class AppConfig {
  AppConfig._({
    required this.environment,
    required this.enableVerboseLogs,
  });

  /// Single resolved config (compile-time defines).
  factory AppConfig.compile() {
    return AppConfig._(
      environment: AppEnvironment.current,
      enableVerboseLogs: kDebugMode &&
          const bool.fromEnvironment('VERBOSE_LOGS', defaultValue: false),
    );
  }

  final AppEnvironment environment;
  final bool enableVerboseLogs;

  /// Material debug banner (keep off for kiosk builds).
  bool get showDebugBanner => kDebugMode && environment == AppEnvironment.dev;

  @override
  String toString() =>
      'AppConfig(env: $environment, offline: true, verbose: $enableVerboseLogs)';
}

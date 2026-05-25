import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/config/app_config.dart';
import 'package:attendance_kiosk_app/core/config/app_environment.dart';

/// Resolved once per [ProviderContainer] (default Riverpod caching).
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.compile());

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  return ref.watch(appConfigProvider).environment;
});

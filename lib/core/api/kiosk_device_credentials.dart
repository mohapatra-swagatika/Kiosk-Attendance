import 'package:attendance_kiosk_app/core/api/kiosk_pair_api_urls.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';

/// Bearer token + API host for kiosk HTTP calls (events, employee snapshot, …).
class KioskDeviceCredentials {
  const KioskDeviceCredentials({
    required this.apiHost,
    required this.deviceToken,
  });

  final String apiHost;
  final String deviceToken;

  bool get isValid => apiHost.isNotEmpty && deviceToken.isNotEmpty;

  static KioskDeviceCredentials fromConfig(KioskConfig? config) {
    if (config == null) {
      return const KioskDeviceCredentials(apiHost: '', deviceToken: '');
    }
    return KioskDeviceCredentials(
      apiHost: resolveApiHost(config),
      deviceToken: config.deviceToken?.trim() ?? '',
    );
  }

  static String resolveApiHost(KioskConfig config) {
    final base = config.apiBaseUrl?.trim();
    if (base != null && base.isNotEmpty) {
      final host = base.replaceFirst(RegExp(r'^https?://'), '').split('/').first;
      return KioskPairApiUrls.toApiHost(host);
    }
    return KioskPairApiUrls.toApiHost(config.domain);
  }
}

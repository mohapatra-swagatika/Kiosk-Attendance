/// Builds kiosk pairing API URLs from the tenant subdomain entered at registration.
class KioskPairApiUrls {
  KioskPairApiUrls._();

  static const String apiHostSuffix = 'thinksys.com';
  static const String pairPath = '/api/v1/kiosk/pair';
  static const String employeeSnapshotPathPrefix = '/api/v1/kiosk/devices';
  static const String employeeSnapshotPathSuffix = '/employee-snapshot';

  /// `thinksysnoida-qa` → `https://thinksysnoida-qa.thinksys.com/api/v1/kiosk/pair`
  static String pairEndpoint(String domainInput) {
    final host = toApiHost(domainInput);
    return 'https://$host$pairPath';
  }

  /// API host used for sync and stored in [KioskConfig.domain].
  static String toApiHost(String domainInput) {
    var part = domainInput.trim().toLowerCase();
    if (part.isEmpty) return '';

    part = part.replaceFirst(RegExp(r'^https?://'), '');
    part = part.split('/').first;

    final suffix = '.$apiHostSuffix';
    if (part.endsWith(suffix)) return part;
    if (part == apiHostSuffix) return apiHostSuffix;
    if (part.contains('.')) return part;
    return '$part$suffix';
  }

  /// Subdomain label for read-only login field.
  static String subdomainFromStored(String stored) {
    final value = stored.trim().toLowerCase();
    if (value.isEmpty) return '';

    final suffix = '.$apiHostSuffix';
    if (value.endsWith(suffix)) {
      return value.substring(0, value.length - suffix.length);
    }
    if (value == apiHostSuffix) return '';
    if (!value.contains('.')) return value;
    return value.split('.').first;
  }

  static String get suffixLabel => '.$apiHostSuffix';

  /// `GET /api/v1/kiosk/devices/{deviceId}/employee-snapshot`
  static String employeeSnapshotEndpoint(String apiHost, String deviceId) {
    final host = toApiHost(apiHost);
    final id = deviceId.trim();
    return 'https://$host$employeeSnapshotPathPrefix/$id$employeeSnapshotPathSuffix';
  }
}

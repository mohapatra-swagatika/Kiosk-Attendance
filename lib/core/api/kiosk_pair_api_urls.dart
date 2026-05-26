/// Builds kiosk pairing API URLs from the tenant subdomain entered at registration.
class KioskPairApiUrls {
  KioskPairApiUrls._();

  static const String apiHostSuffix = 'thinksys.com';
  static const String pairPath = '/api/v1/kiosk/pair';
  static const String employeeSnapshotPathPrefix = '/api/v1/kiosk/devices';
  static const String employeeSnapshotPathSuffix = '/employee-snapshot';
  static const String syncEmployeesPathSuffix = '/sync-employees';
  static const String bulkEventsPath = '/api/v1/kiosk/events/bulk';
  static const String faceDataPathSuffix = '/face-data';

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

  /// `POST /api/v1/kiosk/devices/{deviceId}/sync-employees`
  static String syncEmployeesEndpoint(String apiHost, String deviceId) {
    final host = toApiHost(apiHost);
    final id = deviceId.trim();
    return 'https://$host$employeeSnapshotPathPrefix/$id$syncEmployeesPathSuffix';
  }

  /// `POST /api/v1/kiosk/events/bulk`
  static String bulkEventsEndpoint(String apiHost) {
    final host = toApiHost(apiHost);
    return 'https://$host$bulkEventsPath';
  }

  /// `POST /api/v1/kiosk/devices/{deviceId}/employees/{employeeId}/face-data`
  static String faceDataEndpoint(
    String apiHost,
    String deviceId,
    String employeeId,
  ) {
    final host = toApiHost(apiHost);
    final device = deviceId.trim();
    final employee = employeeId.trim();
    return 'https://$host$employeeSnapshotPathPrefix/$device/employees/$employee$faceDataPathSuffix';
  }

  /// Resolves a relative branding asset path against the tenant API root.
  static String? resolveAssetUrl(String? url, String? apiBaseUrl) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }
    final base = apiBaseUrl?.trim();
    if (base == null || base.isEmpty) return trimmed;
    final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$root$path';
  }
}

/// Fixed Workday-style domain suffix for kiosk registration and login.
class KioskDomain {
  KioskDomain._();

  static const String suffix = 'myworkmyday.com';

  /// Builds the full host from a user-entered subdomain (first part only).
  static String toFullDomain(String subdomain) {
    final part = subdomain.trim().toLowerCase();
    if (part.isEmpty) return '';

    final suffixLower = '.$suffix';
    if (part.endsWith(suffixLower)) {
      return part;
    }
    if (part == suffix) return suffix;

    // If they pasted a full hostname, keep it.
    if (part.contains('.') && !part.endsWith(suffixLower)) {
      return part;
    }

    return '$part.$suffix';
  }

  /// Returns only the subdomain for display (login read-only field).
  static String subdomainFromStored(String stored) {
    final value = stored.trim().toLowerCase();
    if (value.isEmpty) return '';

    const thinksysSuffix = '.thinksys.com';
    if (value.endsWith(thinksysSuffix)) {
      return value.substring(0, value.length - thinksysSuffix.length);
    }

    final suffixLower = '.$suffix';
    if (value.endsWith(suffixLower)) {
      return value.substring(0, value.length - suffixLower.length);
    }
    if (value == suffix) return '';

    // Legacy: value saved as subdomain only.
    if (!value.contains('.')) return value;

    return value.split('.').first;
  }

  static String get suffixLabel => '.$suffix';
}

import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_organization.dart';

/// Parses `data.organization` from the kiosk pair response.
abstract final class PairOrganizationParser {
  static KioskOrganization? fromPairData(Map<String, dynamic>? data) {
    if (data == null) return null;

    final org = _asMap(data['organization']);
    if (org == null) return null;

    final subdomain = _readString(org, const ['subdomain', 'orgSubdomain', 'code']);
    final companyName = _readString(org, const [
      'companyName',
      'company_name',
      'legalName',
    ]);
    final displayName = _readString(org, const [
      'displayName',
      'display_name',
      'name',
    ]);
    final logoUrl = _readString(org, const [
      'companyLogoUrl',
      'company_logo_url',
      'companyLogo',
      'company_logo',
      'logoUrl',
      'logo_url',
    ]);

    if (subdomain == null &&
        companyName == null &&
        displayName == null &&
        logoUrl == null) {
      return null;
    }

    return KioskOrganization(
      subdomain: subdomain,
      companyName: companyName,
      displayName: displayName,
      companyLogoUrl: logoUrl,
    );
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString();
    }
    return null;
  }
}

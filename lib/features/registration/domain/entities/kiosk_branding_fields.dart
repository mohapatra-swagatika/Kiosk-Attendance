import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_organization.dart';

/// Denormalized organization branding fields for reliable Hive persistence.
class KioskBrandingFields {
  const KioskBrandingFields({
    this.subdomain,
    this.companyName,
    this.displayName,
    this.companyLogoUrl,
  });

  final String? subdomain;
  final String? companyName;
  final String? displayName;
  final String? companyLogoUrl;

  factory KioskBrandingFields.fromOrganization(KioskOrganization? org) {
    if (org == null) return const KioskBrandingFields();
    return KioskBrandingFields(
      subdomain: org.subdomain,
      companyName: org.companyName,
      displayName: org.displayName,
      companyLogoUrl: org.companyLogoUrl,
    );
  }

  KioskOrganization? toOrganization() {
    final hasAny = (subdomain?.trim().isNotEmpty ?? false) ||
        (companyName?.trim().isNotEmpty ?? false) ||
        (displayName?.trim().isNotEmpty ?? false) ||
        (companyLogoUrl?.trim().isNotEmpty ?? false);
    if (!hasAny) return null;
    return KioskOrganization(
      subdomain: subdomain,
      companyName: companyName,
      displayName: displayName,
      companyLogoUrl: companyLogoUrl,
    );
  }

  /// Label shown in UI — prefers [companyName], then [displayName].
  String get companyNameForDisplay {
    final name = companyName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return displayName?.trim() ?? '';
  }
}

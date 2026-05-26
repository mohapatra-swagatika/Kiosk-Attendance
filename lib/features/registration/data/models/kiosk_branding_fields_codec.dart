import 'package:attendance_kiosk_app/features/registration/data/models/kiosk_organization_model.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_branding_fields.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_organization.dart';

abstract final class KioskBrandingFieldsCodec {
  static KioskBrandingFields fromJson(Map<String, dynamic> json) {
    final nested = json['organization'];
    if (nested is Map) {
      final org = KioskOrganizationModel.fromJson(
        Map<String, dynamic>.from(nested),
      );
      return KioskBrandingFields.fromOrganization(org.toEntity());
    }

    return KioskBrandingFields(
      subdomain: _read(json, const [
        'organizationSubdomain',
        'orgSubdomain',
        'subdomain',
      ]),
      companyName: _read(json, const [
        'organizationCompanyName',
        'companyName',
        'company_name',
        'legalName',
      ]),
      displayName: _read(json, const [
        'organizationDisplayName',
        'displayName',
        'display_name',
      ]),
      companyLogoUrl: _read(json, const [
        'organizationCompanyLogoUrl',
        'companyLogoUrl',
        'company_logo_url',
        'companyLogo',
        'logoUrl',
      ]),
    );
  }

  static Map<String, dynamic> toJson(KioskBrandingFields fields) {
    final org = fields.toOrganization();
    return {
      if (org != null) 'organization': KioskOrganizationModel.fromEntity(org).toJson(),
      if (fields.subdomain != null) 'organizationSubdomain': fields.subdomain,
      if (fields.companyName != null) 'organizationCompanyName': fields.companyName,
      if (fields.displayName != null) 'organizationDisplayName': fields.displayName,
      if (fields.companyLogoUrl != null)
        'organizationCompanyLogoUrl': fields.companyLogoUrl,
    };
  }

  static KioskBrandingFields fromOrganization(KioskOrganization? org) =>
      KioskBrandingFields.fromOrganization(org);

  static String? _read(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString();
    }
    return null;
  }
}

import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_organization.dart';

class KioskOrganizationModel {
  const KioskOrganizationModel({
    this.subdomain,
    this.companyName,
    this.displayName,
    this.companyLogoUrl,
  });

  factory KioskOrganizationModel.fromEntity(KioskOrganization e) =>
      KioskOrganizationModel(
        subdomain: e.subdomain,
        companyName: e.companyName,
        displayName: e.displayName,
        companyLogoUrl: e.companyLogoUrl,
      );

  factory KioskOrganizationModel.fromJson(Map<String, dynamic> json) {
    return KioskOrganizationModel(
      subdomain: _read(json, const ['subdomain', 'orgSubdomain', 'code']),
      companyName: _read(json, const [
        'companyName',
        'company_name',
        'legalName',
        'legal_name',
      ]),
      displayName: _read(json, const [
        'displayName',
        'display_name',
        'name',
      ]),
      companyLogoUrl: _read(json, const [
        'companyLogoUrl',
        'company_logo_url',
        'companyLogo',
        'company_logo',
        'logoUrl',
        'logo_url',
      ]),
    );
  }

  final String? subdomain;
  final String? companyName;
  final String? displayName;
  final String? companyLogoUrl;

  KioskOrganization toEntity() => KioskOrganization(
        subdomain: subdomain,
        companyName: companyName,
        displayName: displayName,
        companyLogoUrl: companyLogoUrl,
      );

  Map<String, dynamic> toJson() => {
        if (subdomain != null) 'subdomain': subdomain,
        if (companyName != null) 'companyName': companyName,
        if (displayName != null) 'displayName': displayName,
        if (companyLogoUrl != null) 'companyLogoUrl': companyLogoUrl,
      };

  static String? _read(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString();
    }
    return null;
  }
}

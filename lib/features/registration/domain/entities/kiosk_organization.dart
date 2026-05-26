import 'package:equatable/equatable.dart';

/// Tenant branding from the kiosk pair API (`data.organization`).
class KioskOrganization extends Equatable {
  const KioskOrganization({
    this.subdomain,
    this.companyName,
    this.displayName,
    this.companyLogoUrl,
  });

  final String? subdomain;
  final String? companyName;
  final String? displayName;
  final String? companyLogoUrl;

  bool get hasBrandingText =>
      (displayName?.trim().isNotEmpty ?? false) ||
      (companyName?.trim().isNotEmpty ?? false) ||
      (subdomain?.trim().isNotEmpty ?? false);

  String get primaryTitle {
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final company = companyName?.trim();
    if (company != null && company.isNotEmpty) return company;
    return subdomain?.trim() ?? '';
  }

  String get organizationCode => subdomain?.trim() ?? '';

  @override
  List<Object?> get props => [subdomain, companyName, displayName, companyLogoUrl];
}

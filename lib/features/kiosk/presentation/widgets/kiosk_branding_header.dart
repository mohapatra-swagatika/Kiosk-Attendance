import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/kiosk_organization_branding.dart';

/// Sidebar / drawer header: organization logo then company name.
class KioskBrandingHeader extends StatelessWidget {
  const KioskBrandingHeader({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return KioskOrganizationBranding(compact: compact);
  }
}

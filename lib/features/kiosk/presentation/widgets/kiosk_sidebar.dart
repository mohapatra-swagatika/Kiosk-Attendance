import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/config/attendance_mode.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/kiosk_branding_header.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/kiosk_mode_view.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

class KioskSidebar extends ConsumerWidget {
  const KioskSidebar({
    super.key,
    required this.currentView,
    required this.onViewChanged,
  });

  final KioskModeView currentView;
  final ValueChanged<KioskModeView> onViewChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(kioskConfigProvider).valueOrNull?.attendanceMode ??
        AttendanceMode.face;

    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KioskBrandingHeader(),
            const Divider(height: 1),
            if (mode == AttendanceMode.face)
              _NavTile(
                icon: Icons.face_retouching_natural,
                label: KioskSidebarStrings.faceScan,
                selected: currentView == KioskModeView.faceScan,
                onTap: () => onViewChanged(KioskModeView.faceScan),
              )
            else
              _NavTile(
                icon: Icons.pin_outlined,
                label: KioskSidebarStrings.pinAttendance,
                selected: currentView == KioskModeView.pinAttendance,
                onTap: () => onViewChanged(KioskModeView.pinAttendance),
              ),
            _NavTile(
              icon: Icons.login_outlined,
              label: KioskSidebarStrings.loginWithPin,
              selected: currentView == KioskModeView.pinLogin,
              onTap: () => onViewChanged(KioskModeView.pinLogin),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: onTap,
    );
  }
}

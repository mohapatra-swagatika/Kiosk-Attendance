import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/app/theme/theme_mode_notifier.dart';
import 'package:attendance_kiosk_app/core/config/attendance_mode.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/widgets/dashboard/dashboard_hero_header.dart';
import 'package:attendance_kiosk_app/features/auth/login/presentation/providers/login_providers.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

/// Device settings — attendance mode (admin) and device info.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _saving = false;

  Future<void> _setMode(AttendanceMode mode) async {
    setState(() => _saving = true);
    final result =
        await ref.read(kioskConfigRepositoryProvider).updateAttendanceMode(mode);
    ref.invalidate(kioskConfigProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      ),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(KioskSettingsStrings.modeSaved)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(kioskConfigProvider);
    final isAdmin = ref.watch(appSessionProvider).valueOrNull?.isAdmin ?? false;
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (config) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const DashboardHeroHeader(
              eyebrow: AppStrings.menu,
              title: KioskSidebarStrings.settings,
              subtitle: KioskSettingsStrings.offlineNote,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      KioskSettingsStrings.appearanceTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(KioskSettingsStrings.themeLight),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(KioskSettingsStrings.themeDark),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(KioskSettingsStrings.themeSystem),
                          icon: Icon(Icons.brightness_auto_outlined),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (set) =>
                          ref.read(themeModeProvider.notifier).setMode(set.first),
                    ),
                  ],
                ),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        KioskSettingsStrings.attendanceModeTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        KioskSettingsStrings.attendanceModeSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<AttendanceMode>(
                        segments: const [
                          ButtonSegment(
                            value: AttendanceMode.face,
                            label: Text(KioskSettingsStrings.faceMode),
                            icon: Icon(Icons.face_retouching_natural),
                          ),
                          ButtonSegment(
                            value: AttendanceMode.pin,
                            label: Text(KioskSettingsStrings.pinMode),
                            icon: Icon(Icons.pin_outlined),
                          ),
                        ],
                        selected: {config?.attendanceMode ?? AttendanceMode.face},
                        onSelectionChanged: _saving
                            ? null
                            : (set) => _setMode(set.first),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      KioskSettingsStrings.deviceInfoTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (config == null)
                      Text(
                        KioskSettingsStrings.noConfig,
                        style: Theme.of(context).textTheme.bodyLarge,
                      )
                    else ...[
                      _row(context, KioskSettingsStrings.domainLabel, config.domain),
                      _row(context, KioskSettingsStrings.machineLabel, config.machineName),
                      _row(context, KioskSettingsStrings.codeLabel, config.code),
                      if (config.adminName != null)
                        _row(context, KioskSettingsStrings.adminLabel, config.adminName!),
                      if (config.adminEmail != null)
                        _row(context, KioskSettingsStrings.emailLabel, config.adminEmail!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

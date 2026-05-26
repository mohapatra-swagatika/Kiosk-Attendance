import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/app/router/app_router.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/presentation/kiosk_events_sync_listener.dart';
import 'package:attendance_kiosk_app/app/theme/app_theme.dart';
import 'package:attendance_kiosk_app/app/theme/theme_mode_notifier.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';

class AttendanceApp extends ConsumerWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return KioskEventsSyncListener(
      child: MaterialApp.router(
        title: AppStrings.appTitle,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

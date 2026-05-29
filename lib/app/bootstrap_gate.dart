import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/app/app_startup_coordinator.dart';
import 'package:attendance_kiosk_app/app/attendance_app.dart';
import 'package:attendance_kiosk_app/app/bootstrap.dart';

/// Renders the app on the first frame; storage init runs in the background.
class BootstrapGate extends ConsumerStatefulWidget {
  const BootstrapGate({super.key});

  @override
  ConsumerState<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends ConsumerState<BootstrapGate> {
  @override
  void initState() {
    super.initState();
    // Defer Hive so the first taps on the registration form are not competing
    // with box I/O on the UI isolate (especially on cold first install).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      ref.read(appStartupCoordinatorProvider.notifier).runStorageBootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fatalError = ref.watch(
      appStartupCoordinatorProvider.select((s) => s.fatalError),
    );
    if (fatalError != null) {
      return bootstrapErrorApp(fatalError);
    }
    return const AttendanceApp();
  }
}

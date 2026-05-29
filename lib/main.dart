import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/app/app_launch_gate.dart';
import 'package:attendance_kiosk_app/app/bootstrap_gate.dart';
import 'package:attendance_kiosk_app/core/storage/hive_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await HiveInitializer.init();
    AppLaunchGate.markStorageReady();
    await AppLaunchGate.preload();
  } catch (e, st) {
    debugPrint('main: early storage preload failed — $e\n$st');
  }
  runApp(const ProviderScope(child: BootstrapGate()));
}

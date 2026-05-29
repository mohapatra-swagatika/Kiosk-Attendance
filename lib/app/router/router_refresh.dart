import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/app/app_launch_gate.dart';

/// Notifies [GoRouter] after registration / auth storage changes.
final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

class RouterRefreshNotifier extends ChangeNotifier {
  void notify() {
    AppLaunchGate.invalidate();
    notifyListeners();
  }

  /// Refreshes routing flags from Hive, then notifies [GoRouter] (no stale cache).
  Future<void> reloadAndNotify() async {
    if (AppLaunchGate.isStorageReady) {
      await AppLaunchGate.preload();
    } else {
      AppLaunchGate.invalidate();
    }
    notifyListeners();
  }
}

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/face_data_sync/face_data_sync_providers.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/kiosk_events_providers.dart';
import 'package:attendance_kiosk_app/core/network/network_connectivity.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';
import 'package:attendance_kiosk_app/app/app_launch_gate.dart';
import 'package:attendance_kiosk_app/app/app_startup_coordinator.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';

/// Listens for connectivity changes and flushes offline queues (events + face data).
class KioskEventsSyncListener extends ConsumerStatefulWidget {
  const KioskEventsSyncListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KioskEventsSyncListener> createState() =>
      _KioskEventsSyncListenerState();
}

class _KioskEventsSyncListenerState extends ConsumerState<KioskEventsSyncListener> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    // Defer background syncing so first user interaction (text input focus,
    // keyboard open, route transition) is never competing with I/O work.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Future<void>.delayed(const Duration(milliseconds: 2500), _bootstrap),
    );
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final storageReady = ref.read(appStartupCoordinatorProvider).storageReady;
    if (!storageReady) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      return _bootstrap();
    }

    final connectivity = ref.read(networkConnectivityProvider);
    final online = await connectivity.hasConnection();
    _wasOffline = !online;
    if (online) unawaited(_flushQueueIfPaired());
    _subscription = connectivity.onConnectivityChanged.listen(_onConnectivity);
  }

  Future<void> _onConnectivity(List<ConnectivityResult> results) async {
    final online = NetworkConnectivity.isOnline(results);
    if (online && _wasOffline) {
      unawaited(_flushQueueIfPaired());
    }
    _wasOffline = !online;
  }

  Future<void> _flushQueueIfPaired() async {
    if (!AppLaunchGate.isStorageReady) return;

    // On first install, the app sits on Registration. Syncing is unnecessary
    // there and can cause UI jank while the keyboard/focus animation starts.
    final hasEither =
        await ref.read(hasKioskConfigUseCaseProvider)(const NoParams());
    final hasConfig = hasEither.fold((_) => false, (v) => v);
    if (!hasConfig) return;

    await ref.read(kioskEventsRepositoryProvider).syncPending();
    await ref.read(faceDataSyncRepositoryProvider).syncPending();
    ref.invalidate(kioskEventsPendingCountProvider);
    ref.invalidate(kioskEventsLastSyncProvider);
    ref.invalidate(faceDataSyncPendingCountProvider);
    ref.invalidate(faceDataSyncLastSyncProvider);
    ref.invalidate(offlineSyncPendingCountProvider);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

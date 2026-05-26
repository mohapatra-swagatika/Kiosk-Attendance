import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/face_data_sync/face_data_sync_providers.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/kiosk_events_providers.dart';
import 'package:attendance_kiosk_app/core/network/network_connectivity.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final connectivity = ref.read(networkConnectivityProvider);
    final online = await connectivity.hasConnection();
    _wasOffline = !online;
    if (online) {
      await _flushQueue();
    }
    _subscription = connectivity.onConnectivityChanged.listen(_onConnectivity);
  }

  Future<void> _onConnectivity(List<ConnectivityResult> results) async {
    final online = NetworkConnectivity.isOnline(results);
    if (online && _wasOffline) {
      await _flushQueue();
    }
    _wasOffline = !online;
  }

  Future<void> _flushQueue() async {
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

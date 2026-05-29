import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/app/app_launch_gate.dart';
import 'package:attendance_kiosk_app/app/bootstrap.dart' show appMlBootstrapComplete;
import 'package:attendance_kiosk_app/app/router/router_refresh.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/storage/hive_initializer.dart';
import 'package:attendance_kiosk_app/core/ui/ui_yield.dart';

/// Tracks first-launch storage init and optional background service warm-up.
///
/// Storage opens asynchronously so the registration form can accept input
/// immediately while a non-blocking banner shows progress.
class AppStartupState {
  const AppStartupState({
    this.storageReady = false,
    this.storageStatus,
    this.backgroundStatus,
    this.fatalError,
  });

  final bool storageReady;
  final String? storageStatus;
  final String? backgroundStatus;
  final String? fatalError;

  bool get showStorageBanner =>
      !storageReady && fatalError == null && storageStatus != null;

  bool get showBackgroundBanner =>
      storageReady && backgroundStatus != null && backgroundStatus!.isNotEmpty;

  AppStartupState copyWith({
    bool? storageReady,
    Object? storageStatus = _unset,
    Object? backgroundStatus = _unset,
    Object? fatalError = _unset,
  }) {
    return AppStartupState(
      storageReady: storageReady ?? this.storageReady,
      storageStatus: identical(storageStatus, _unset)
          ? this.storageStatus
          : storageStatus as String?,
      backgroundStatus: identical(backgroundStatus, _unset)
          ? this.backgroundStatus
          : backgroundStatus as String?,
      fatalError: identical(fatalError, _unset)
          ? this.fatalError
          : fatalError as String?,
    );
  }

  static const _unset = Object();
}

class AppStartupCoordinator extends Notifier<AppStartupState> {
  bool _started = false;

  @override
  AppStartupState build() => const AppStartupState();

  /// Opens Hive and preloads routing flags without blocking the first frame.
  Future<void> runStorageBootstrap() async {
    if (state.storageReady) return;
    if (_started) {
      await HiveInitializer.init();
      if (state.storageReady) return;
    }
    _started = true;

    if (!HiveInitializer.isInitialized) {
      state = state.copyWith(storageStatus: 'Opening local storage…');
    }
    await yieldToUi();

    try {
      await HiveInitializer.init();
      await yieldToUi();
      AppLaunchGate.markStorageReady();
      await AppLaunchGate.preload();

      FaceEmbeddingCodec.setMode(FaceEmbeddingMode.tflite);
      appMlBootstrapComplete = true;

      state = state.copyWith(
        storageReady: true,
        storageStatus: null,
      );

      await ref.read(routerRefreshProvider).reloadAndNotify();

      if (kDebugMode) {
        debugPrint(
          'AppStartup: storage ready (hasConfig=${AppLaunchGate.cached.hasConfig})',
        );
      }
    } catch (e, st) {
      debugPrint('AppStartup: storage failed — $e\n$st');
      state = state.copyWith(
        fatalError: 'Storage init failed: $e',
        storageStatus: null,
      );
    }
  }

  void setBackgroundStatus(String? message) {
    if (state.backgroundStatus == message) return;
    state = state.copyWith(backgroundStatus: message);
  }
}

final appStartupCoordinatorProvider =
    NotifierProvider<AppStartupCoordinator, AppStartupState>(
  AppStartupCoordinator.new,
);

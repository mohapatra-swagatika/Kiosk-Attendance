import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee_sync_result.dart';
import 'package:attendance_kiosk_app/features/employees/domain/usecases/sync_employees_usecase.dart';

class EmployeeSyncUiState {
  const EmployeeSyncUiState({
    this.isSyncing = false,
    this.metadata = const EmployeeSyncMetadata(),
  });

  final bool isSyncing;
  final EmployeeSyncMetadata metadata;

  EmployeeSyncUiState copyWith({
    bool? isSyncing,
    EmployeeSyncMetadata? metadata,
  }) {
    return EmployeeSyncUiState(
      isSyncing: isSyncing ?? this.isSyncing,
      metadata: metadata ?? this.metadata,
    );
  }
}

class EmployeeSyncNotifier extends StateNotifier<EmployeeSyncUiState> {
  EmployeeSyncNotifier(this._sync, this._loadMetadata)
      : super(const EmployeeSyncUiState()) {
    unawaited(_refreshMetadata());
  }

  final SyncEmployeesUseCase _sync;
  final Future<EmployeeSyncMetadata> Function() _loadMetadata;

  Future<void> _refreshMetadata() async {
    final meta = await _loadMetadata();
    if (!mounted) return;
    state = state.copyWith(metadata: meta);
  }

  /// Returns `true` when sync completed successfully.
  Future<bool> syncEmployees() async {
    if (state.isSyncing) return false;

    state = state.copyWith(
      isSyncing: true,
      metadata: state.metadata.copyWith(clearError: true),
    );

    final result = await _sync(const NoParams());
    if (!mounted) return false;

    return result.fold(
      (failure) {
        state = state.copyWith(
          isSyncing: false,
          metadata: state.metadata.copyWith(lastError: failure.message),
        );
        return false;
      },
      (syncResult) {
        state = state.copyWith(
          isSyncing: false,
          metadata: EmployeeSyncMetadata(
            lastSyncedAt: syncResult.syncedAt,
            lastEmployeeCount: syncResult.employeeCount,
          ),
        );
        return true;
      },
    );
  }
}

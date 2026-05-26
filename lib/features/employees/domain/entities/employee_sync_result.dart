import 'package:equatable/equatable.dart';

class EmployeeSyncResult extends Equatable {
  const EmployeeSyncResult({
    required this.employeeCount,
    required this.faceProfileCount,
    required this.syncedAt,
  });

  final int employeeCount;
  final int faceProfileCount;
  final DateTime syncedAt;

  @override
  List<Object?> get props => [employeeCount, faceProfileCount, syncedAt];
}

class EmployeeSyncMetadata extends Equatable {
  const EmployeeSyncMetadata({
    this.lastSyncedAt,
    this.lastEmployeeCount,
    this.lastError,
  });

  final DateTime? lastSyncedAt;
  final int? lastEmployeeCount;
  final String? lastError;

  EmployeeSyncMetadata copyWith({
    DateTime? lastSyncedAt,
    int? lastEmployeeCount,
    String? lastError,
    bool clearError = false,
  }) {
    return EmployeeSyncMetadata(
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastEmployeeCount: lastEmployeeCount ?? this.lastEmployeeCount,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [lastSyncedAt, lastEmployeeCount, lastError];
}

/// Sync state for a queued kiosk attendance event.
enum KioskEventSyncStatus {
  pending('pending'),
  syncing('syncing'),
  synced('synced'),
  failed('failed');

  const KioskEventSyncStatus(this.value);
  final String value;

  static KioskEventSyncStatus fromValue(String? raw) {
    return KioskEventSyncStatus.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => KioskEventSyncStatus.pending,
    );
  }

  bool get isEligibleForSync =>
      this == KioskEventSyncStatus.pending || this == KioskEventSyncStatus.failed;
}

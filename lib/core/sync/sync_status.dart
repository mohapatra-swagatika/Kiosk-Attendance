enum SyncStatus {
  pending('pending'),
  synced('synced'),
  failed('failed');

  const SyncStatus(this.value);
  final String value;

  static SyncStatus fromValue(String? v) =>
      SyncStatus.values.firstWhere((e) => e.value == v, orElse: () => SyncStatus.pending);
}

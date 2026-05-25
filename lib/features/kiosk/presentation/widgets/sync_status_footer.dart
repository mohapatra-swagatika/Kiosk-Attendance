import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/sync/sync_providers.dart';

/// Last sync time, pending count, and sync action — used in the logged-in shell drawer.
class SyncStatusFooter extends ConsumerStatefulWidget {
  const SyncStatusFooter({super.key});

  @override
  ConsumerState<SyncStatusFooter> createState() => _SyncStatusFooterState();
}

class _SyncStatusFooterState extends ConsumerState<SyncStatusFooter> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final result = await ref.read(syncRepositoryProvider).flushPending();
    ref.invalidate(syncMetadataProvider);
    ref.invalidate(syncPendingCountProvider);
    if (!mounted) return;
    setState(() => _syncing = false);
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      ),
      (count) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(KioskSidebarStrings.syncedCount(count))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metadataAsync = ref.watch(syncMetadataProvider);
    final pendingAsync = ref.watch(syncPendingCountProvider);
    final scheme = Theme.of(context).colorScheme;
    final lastSync = metadataAsync.valueOrNull?.lastSyncAt;
    final pending = pendingAsync.valueOrNull ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            KioskSidebarStrings.lastSync,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            lastSync == null
                ? KioskSidebarStrings.neverSynced
                : DateFormat.yMMMd().add_jm().format(lastSync),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (pending > 0) ...[
            const SizedBox(height: 8),
            Text(
              KioskSidebarStrings.pendingCount(pending),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.tertiary,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(KioskSidebarStrings.syncNow),
          ),
        ],
      ),
    );
  }
}

final syncMetadataProvider = FutureProvider((ref) async {
  final result = await ref.read(syncRepositoryProvider).metadata();
  return result.fold((_) => null, (m) => m);
});

final syncPendingCountProvider = FutureProvider((ref) async {
  final result = await ref.read(syncRepositoryProvider).pendingCount();
  return result.fold((_) => 0, (c) => c);
});

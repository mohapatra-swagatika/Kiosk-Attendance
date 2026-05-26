import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:attendance_kiosk_app/app/router/route_paths.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';
import 'package:attendance_kiosk_app/core/widgets/app_error_view.dart';
import 'package:attendance_kiosk_app/core/widgets/app_loading.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee_sync_result.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_sync_providers.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/widgets/employee_card.dart';

/// Employee roster from local Hive storage with tablet-responsive cards.
class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({super.key});

  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  static const _searchDebounceDuration = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _alignSearchFieldWithProvider();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Empty controller vs restored provider (e.g. after route pop).
  void _alignSearchFieldWithProvider() {
    final query = ref.read(employeeSearchQueryProvider);
    if (query.isEmpty) return;
    if (_searchController.text == query) return;
    _searchController.text = query;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      ref.read(employeeSearchQueryProvider.notifier).state = '';
      return;
    }
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      ref.read(employeeSearchQueryProvider.notifier).state = value;
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(employeeSearchQueryProvider.notifier).state = '';
  }

  Future<void> _syncEmployees() async {
    final notifier = ref.read(employeeSyncNotifierProvider.notifier);
    final ok = await notifier.syncEmployees();
    if (!mounted) return;

    if (ok) {
      ref.invalidate(employeesListProvider);
      ref.invalidate(kioskConfigProvider);
      await ref.read(faceRepositoryProvider).preloadGallery();
      if (!mounted) return;
      final meta = ref.read(employeeSyncNotifierProvider).metadata;
      final count = meta.lastEmployeeCount ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(EmployeesStrings.syncedCount(count)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final error =
        ref.read(employeeSyncNotifierProvider).metadata.lastError ??
            EmployeesStrings.syncFailed;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: EmployeesStrings.syncRetry,
          onPressed: _syncEmployees,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(filteredEmployeesListProvider);
    final rosterAsync = ref.watch(employeesListProvider);
    final syncState = ref.watch(employeeSyncNotifierProvider);
    final hasActiveSearch = ref.watch(employeeSearchQueryProvider).trim().isNotEmpty;
    final totalCount = rosterAsync.valueOrNull?.length ?? 0;
    final isSyncing = syncState.isSyncing;

    return async.when(
      data: (employees) {
        if (totalCount == 0) {
          return _EmployeesSearchScaffold(
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            onClearSearch: _clearSearch,
            syncing: isSyncing,
            syncMetadata: syncState.metadata,
            onSync: _syncEmployees,
            child: const Center(child: Text(EmployeesStrings.empty)),
          );
        }
        if (employees.isEmpty && hasActiveSearch) {
          return _EmployeesSearchScaffold(
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            onClearSearch: _clearSearch,
            syncing: isSyncing,
            syncMetadata: syncState.metadata,
            onSync: _syncEmployees,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  EmployeesStrings.noSearchResults,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _EmployeesSearchScaffold(
          searchController: _searchController,
          onSearchChanged: _onSearchChanged,
          onClearSearch: _clearSearch,
          syncing: isSyncing,
          syncMetadata: syncState.metadata,
          onSync: _syncEmployees,
          child: ResponsiveBuilder(
            builder: (context, bp, constraints) {
              final crossCount = switch (bp) {
                AppBreakpointSize.compact => 1,
                AppBreakpointSize.medium => 2,
                AppBreakpointSize.expanded => 3,
              };
              final pad = switch (bp) {
                AppBreakpointSize.compact => 16.0,
                AppBreakpointSize.medium => 24.0,
                AppBreakpointSize.expanded => 28.0,
              };
              const gridSpacing = 16.0;
              final contentWidth = constraints.maxWidth - pad * 2;
              final itemWidth = crossCount <= 1
                  ? contentWidth
                  : (contentWidth - gridSpacing * (crossCount - 1)) / crossCount;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 8, pad, pad + 24),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        spacing: gridSpacing,
                        runSpacing: gridSpacing,
                        children: [
                          for (final e in employees)
                            SizedBox(
                              width: itemWidth,
                              child: EmployeeCard(
                                employee: e,
                                compact: crossCount == 1,
                                onViewDetails: () => context.push(
                                  RoutePaths.employeeDetailPath(e.id),
                                  extra: e,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
      loading: () => const AppLoading(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(employeesListProvider),
      ),
    );
  }
}

class _EmployeesSearchScaffold extends StatelessWidget {
  const _EmployeesSearchScaffold({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.syncing,
    required this.syncMetadata,
    required this.onSync,
    required this.child,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final bool syncing;
  final EmployeeSyncMetadata syncMetadata;
  final VoidCallback onSync;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lastAt = syncMetadata.lastSyncedAt;
    final lastError = syncMetadata.lastError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(EmployeesStrings.title, style: textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(EmployeesStrings.subtitle, style: textTheme.bodyLarge),
              const SizedBox(height: 12),
              SearchBar(
                controller: searchController,
                hintText: EmployeesStrings.searchHint,
                leading: const Icon(Icons.search),
                trailing: [
                  ListenableBuilder(
                    listenable: searchController,
                    builder: (context, _) {
                      if (searchController.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onClearSearch,
                        tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
                      );
                    },
                  ),
                ],
                onChanged: onSearchChanged,
                elevation: WidgetStateProperty.all(0),
                backgroundColor: WidgetStateProperty.all(
                  scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: syncing ? null : onSync,
                  icon: syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                  label: Text(
                    syncing ? EmployeesStrings.syncInProgress : EmployeesStrings.syncEmployees,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                lastAt == null
                    ? EmployeesStrings.syncNever
                    : EmployeesStrings.lastSynced(
                        DateFormat.yMMMd().add_jm().format(lastAt),
                      ),
                style: textTheme.bodySmall?.copyWith(
                  color: lastError != null ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
              if (lastError != null && !syncing) ...[
                const SizedBox(height: 4),
                Text(
                  lastError,
                  style: textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

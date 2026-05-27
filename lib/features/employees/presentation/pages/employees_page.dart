import 'dart:async';
import 'dart:math' as math;

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
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_sync_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/utils/employee_search_filter.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/widgets/employee_card.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

/// Employee roster from local Hive storage with tablet-responsive cards.
class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({super.key});

  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> {
  final _searchController = TextEditingController();
  final _debouncedQuery = ValueNotifier<String>('');
  Timer? _searchDebounce;

  List<Employee>? _indexedRoster;
  List<EmployeeSearchIndexEntry>? _searchIndex;

  static const _searchDebounceDuration = Duration(milliseconds: 300);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _debouncedQuery.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _ensureSearchIndex(List<Employee> roster) {
    if (identical(_indexedRoster, roster)) return;
    _indexedRoster = roster;
    _searchIndex = EmployeeSearchFilter.buildIndex(roster);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      _debouncedQuery.value = '';
      return;
    }
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      _debouncedQuery.value = value;
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _debouncedQuery.value = '';
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
    final rosterAsync = ref.watch(employeesListProvider);

    return rosterAsync.when(
      data: (roster) {
        _ensureSearchIndex(roster);

        return _EmployeesSearchScaffold(
          searchController: _searchController,
          onSearchChanged: _onSearchChanged,
          onClearSearch: _clearSearch,
          onSync: _syncEmployees,
          child: ValueListenableBuilder<String>(
            valueListenable: _debouncedQuery,
            builder: (context, query, _) {
              final filtered = EmployeeSearchFilter.applyIndex(
                roster,
                _searchIndex!,
                query,
              );
              final hasActiveSearch = query.trim().isNotEmpty;

              if (roster.isEmpty) {
                return const Center(child: Text(EmployeesStrings.empty));
              }
              if (filtered.isEmpty && hasActiveSearch) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      EmployeesStrings.noSearchResults,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return _EmployeesRosterGrid(
                employees: filtered,
                onViewDetails: (employee) => context.push(
                  RoutePaths.employeeDetailPath(employee.id),
                  extra: employee,
                ),
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

/// Virtualized grid; only rebuilds when [employees] changes.
class _EmployeesRosterGrid extends StatelessWidget {
  const _EmployeesRosterGrid({
    required this.employees,
    required this.onViewDetails,
  });

  final List<Employee> employees;
  final void Function(Employee employee) onViewDetails;

  static const _gridSpacing = 16.0;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
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
        final contentWidth = constraints.maxWidth - pad * 2;
        final itemWidth = crossCount <= 1
            ? contentWidth
            : (contentWidth - _gridSpacing * (crossCount - 1)) / crossCount;
        final rowCount = (employees.length + crossCount - 1) ~/ crossCount;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 8, pad, pad + 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, rowIndex) {
                    final start = rowIndex * crossCount;
                    final end = math.min(start + crossCount, employees.length);
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: rowIndex < rowCount - 1 ? _gridSpacing : 0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = start; i < end; i++) ...[
                            if (i > start) const SizedBox(width: _gridSpacing),
                            SizedBox(
                              width: itemWidth,
                              child: EmployeeCard(
                                key: ValueKey(employees[i].id),
                                employee: employees[i],
                                compact: crossCount == 1,
                                onViewDetails: () => onViewDetails(employees[i]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  childCount: rowCount,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmployeesSearchScaffold extends StatelessWidget {
  const _EmployeesSearchScaffold({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSync,
    required this.child,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onSync;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EmployeesSearchHeader(
          searchController: searchController,
          onSearchChanged: onSearchChanged,
          onClearSearch: onClearSearch,
          onSync: onSync,
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Title, search field, and sync controls — sync state isolated here.
class _EmployeesSearchHeader extends ConsumerWidget {
  const _EmployeesSearchHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSync,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final syncState = ref.watch(employeeSyncNotifierProvider);
    final syncing = syncState.isSyncing;
    final syncMetadata = syncState.metadata;
    final lastAt = syncMetadata.lastSyncedAt;
    final lastError = syncMetadata.lastError;

    return Padding(
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
    );
  }
}

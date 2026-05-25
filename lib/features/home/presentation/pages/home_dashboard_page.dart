import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';
import 'package:attendance_kiosk_app/core/widgets/app_error_view.dart';
import 'package:attendance_kiosk_app/core/widgets/app_loading.dart';
import 'package:attendance_kiosk_app/core/widgets/dashboard/dashboard.dart';
import 'package:attendance_kiosk_app/features/home/domain/entities/dashboard_analytics.dart';
import 'package:attendance_kiosk_app/features/home/presentation/providers/dashboard_analytics_provider.dart';
import 'package:attendance_kiosk_app/features/home/presentation/widgets/attendance_analytics_widgets.dart';

/// Analytics-focused home: attendance rates, punctuality, and performance KPIs.
class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final analyticsAsync = ref.watch(dashboardAnalyticsProvider);

    return analyticsAsync.when(
      loading: () => const Center(child: AppLoading()),
      error: (e, _) => AppErrorView(
        message: HomeStrings.analyticsError,
        onRetry: () => ref.invalidate(dashboardAnalyticsProvider),
      ),
      data: (analytics) => SingleChildScrollView(
        child: DashboardPageChrome(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardHeroHeader(
                eyebrow: HomeStrings.eyebrow,
                title: HomeStrings.title,
                subtitle: HomeStrings.subtitle,
                trailing: [
                  Icon(Icons.analytics_outlined, size: 20, color: scheme.primary),
                  Icon(Icons.today_outlined, size: 20, color: scheme.secondary),
                ],
              ),
              const SizedBox(height: 24),
              DashboardSectionHeader(
                title: HomeStrings.summaryTitle,
                subtitle: HomeStrings.summarySubtitle(
                  analytics.presentCount,
                  analytics.totalEmployees,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat.yMMMEd().format(analytics.reportDate),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              _AnalyticsBody(analytics: analytics),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.analytics});

  final DashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ResponsiveBuilder(
      builder: (context, bp, _) {
        final ringCards = [
          AttendancePercentageRing(
            title: HomeStrings.attendanceRateTitle,
            percentage: analytics.attendancePercentage,
            subtitle: HomeStrings.attendanceRateDetail(
              analytics.presentCount,
              analytics.totalEmployees,
            ),
            color: scheme.primary,
            icon: Icons.how_to_reg_rounded,
          ),
          AttendancePercentageRing(
            title: HomeStrings.lateRateTitle,
            percentage: analytics.lateCheckInPercentage,
            subtitle: HomeStrings.lateRateDetail(
              analytics.lateCheckInCount,
              analytics.presentCount,
            ),
            color: Colors.orange.shade700,
            icon: Icons.schedule_rounded,
          ),
        ];

        final wide = bp != AppBreakpointSize.compact;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OverallPerformanceCard(
              analytics: analytics,
              title: HomeStrings.performanceTitle,
              subtitle: HomeStrings.performanceSubtitle,
              presentLabel: HomeStrings.statPresent,
              lateLabel: HomeStrings.statLate,
              rosterLabel: HomeStrings.statRoster,
            ),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ringCards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: ringCards[1]),
                ],
              )
            else ...[
              ringCards[0],
              const SizedBox(height: 16),
              ringCards[1],
            ],
            const SizedBox(height: 20),
            PresentAbsentBreakdownBar(
              title: HomeStrings.presentVsAbsentTitle,
              presentPercent: analytics.attendancePercentage,
              absentPercent: analytics.absentPercentage,
              presentLegend: HomeStrings.presentLegend,
              absentLegend: HomeStrings.absentLegend,
            ),
            const SizedBox(height: 20),
            DashboardMetricStrip(
              metrics: [
                DashboardMetric(
                  icon: Icons.groups_rounded,
                  label: HomeStrings.statRoster,
                  value: '${analytics.totalEmployees}',
                  tint: scheme.primary,
                ),
                DashboardMetric(
                  icon: Icons.person_pin_circle,
                  label: HomeStrings.statPresent,
                  value: '${analytics.presentCount}',
                  tint: Colors.green.shade600,
                ),
                DashboardMetric(
                  icon: Icons.person_off_outlined,
                  label: HomeStrings.absentLegend,
                  value: '${analytics.absentCount}',
                  tint: scheme.outline,
                ),
                DashboardMetric(
                  icon: Icons.warning_amber_rounded,
                  label: HomeStrings.statLate,
                  value: '${analytics.lateCheckInCount}',
                  tint: Colors.orange.shade700,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

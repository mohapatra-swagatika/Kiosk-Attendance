import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/core/widgets/glass_panel.dart';
import 'package:attendance_kiosk_app/features/home/domain/entities/dashboard_analytics.dart';

/// Circular KPI: percentage ring + label + detail line.
class AttendancePercentageRing extends StatelessWidget {
  const AttendancePercentageRing({
    super.key,
    required this.title,
    required this.percentage,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final double percentage;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = percentage.clamp(0, 100) / 100;

    return GlassPanel(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 10,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: color,
                  ),
                  Center(
                    child: Text(
                      '${percentage.round()}%',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

/// Stacked bar for present vs absent share of roster.
class PresentAbsentBreakdownBar extends StatelessWidget {
  const PresentAbsentBreakdownBar({
    super.key,
    required this.title,
    required this.presentPercent,
    required this.absentPercent,
    required this.presentLegend,
    required this.absentLegend,
  });

  final String title;
  final double presentPercent;
  final double absentPercent;
  final String presentLegend;
  final String absentLegend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final present = presentPercent.clamp(0, 100);
    final absent = absentPercent.clamp(0, 100);
    final total = present + absent;
    final presentFlex = total > 0 ? (present / total * 100).round().clamp(1, 99) : 50;
    final absentFlex = 100 - presentFlex;

    return GlassPanel(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                    flex: presentFlex,
                    child: ColoredBox(color: scheme.primary),
                  ),
                  Expanded(
                    flex: absentFlex,
                    child: ColoredBox(color: scheme.outline.withValues(alpha: 0.35)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _LegendDot(color: scheme.primary, label: '${present.round()}% $presentLegend'),
              const SizedBox(width: 16),
              _LegendDot(
                color: scheme.outline.withValues(alpha: 0.5),
                label: '${absent.round()}% $absentLegend',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

/// Large overall performance card with score and supporting stats.
class OverallPerformanceCard extends StatelessWidget {
  const OverallPerformanceCard({
    super.key,
    required this.analytics,
    required this.title,
    required this.subtitle,
    required this.presentLabel,
    required this.lateLabel,
    required this.rosterLabel,
  });

  final DashboardAnalytics analytics;
  final String title;
  final String subtitle;
  final String presentLabel;
  final String lateLabel;
  final String rosterLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = analytics.performanceScore.round();

    Color scoreColor;
    if (score >= 85) {
      scoreColor = Colors.green.shade600;
    } else if (score >= 70) {
      scoreColor = scheme.primary;
    } else {
      scoreColor = Colors.orange.shade700;
    }

    return GlassPanel(
      borderRadius: 22,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 9,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: scoreColor,
                    ),
                    Center(
                      child: Text(
                        '$score',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scoreColor,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow(
                      icon: Icons.check_circle_outline,
                      label: presentLabel,
                      value: '${analytics.presentCount} / ${analytics.totalEmployees}',
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 8),
                    _StatRow(
                      icon: Icons.schedule,
                      label: lateLabel,
                      value: '${analytics.lateCheckInCount}',
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(height: 8),
                    _StatRow(
                      icon: Icons.groups_outlined,
                      label: rosterLabel,
                      value: '${analytics.totalEmployees}',
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/core/widgets/glass_panel.dart';

/// Single metric for [DashboardMetricStrip] or standalone use.
class DashboardMetric {
  const DashboardMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tint;
}

/// Horizontal strip of frosted metric chips (KPIs, counts, status).
class DashboardMetricStrip extends StatelessWidget {
  const DashboardMetricStrip({
    super.key,
    required this.metrics,
    this.spacing = 12,
  });

  final List<DashboardMetric> metrics;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useWrap = constraints.maxWidth < 420;
        final children = metrics.map((m) => _MetricChip(metric: m)).toList();
        if (useWrap) {
          return Wrap(spacing: spacing, runSpacing: spacing, children: children);
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = metric.tint ?? scheme.primary;

    return GlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(metric.icon, color: tint, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';

/// Header with date picker and previous/next day navigation (responsive).
class AttendanceDateFilterBar extends StatelessWidget {
  const AttendanceDateFilterBar({
    super.key,
    required this.title,
    required this.selectedDay,
    required this.onDateChanged,
    this.subtitle,
    this.showTitle = true,
  });

  final String title;
  final String? subtitle;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDateChanged;

  /// When false, only date picker + prev/next (for embedded sections with their own heading).
  final bool showTitle;

  static const double _stackedLayoutMaxWidth = 520;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) onDateChanged(picked);
  }

  String _dateLabel(BuildContext context, {required bool compact}) {
    if (compact) {
      return DateFormat.yMMMd().format(selectedDay);
    }
    return DateFormat.yMMMEd().format(selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    final canGoNext = !selectedDay.isAfter(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < _stackedLayoutMaxWidth;
          final compactDate = constraints.maxWidth < 360;
          final dateLabel = _dateLabel(context, compact: compactDate);

          final dateControls = Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(context),
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: EmployeePortalStrings.previousDay,
                onPressed: () => onDateChanged(
                  selectedDay.subtract(const Duration(days: 1)),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: EmployeePortalStrings.nextDay,
                onPressed: canGoNext
                    ? () => onDateChanged(selectedDay.add(const Duration(days: 1)))
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          );

          final hasHeader = showTitle && title.trim().isNotEmpty;

          Widget? header;
          if (hasHeader) {
            header = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: stacked || !hasHeader
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (header != null) ...[
                        header,
                        const SizedBox(height: 10),
                      ],
                      dateControls,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: header!),
                      const SizedBox(width: 8),
                      Flexible(child: dateControls),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

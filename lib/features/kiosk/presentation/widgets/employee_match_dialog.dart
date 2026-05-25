import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

Future<void> showEmployeeMatchDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Employee employee,
  required AttendanceLog? activeLog,
  double? confidence,
  Future<String?> Function()? onCaptureAttendancePhoto,
}) {
  final now = DateTime.now();
  final dateFmt = DateFormat.yMMMEd();
  final timeFmt = DateFormat.jm();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final hasActive = activeLog != null && activeLog.isActiveCheckIn;
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      var attendanceBusy = false;

      return StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        title: const SizedBox.shrink(),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, size: 18, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        FaceIdStrings.verified,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _EmployeeMatchPhoto(imageUrl: employee.imageUrl),
                const SizedBox(height: 16),
                Text(
                  employee.name,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  employee.department,
                  style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _MatchDetailRow(
                  icon: Icons.badge_outlined,
                  label: MatchDialogStrings.employeeId(employee.id),
                ),
                const SizedBox(height: 8),
                _MatchDetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: MatchDialogStrings.date(dateFmt.format(now)),
                ),
                const SizedBox(height: 8),
                _MatchDetailRow(
                  icon: Icons.schedule_outlined,
                  label: MatchDialogStrings.time(timeFmt.format(now)),
                ),
                if (confidence != null) ...[
                  const SizedBox(height: 8),
                  _MatchDetailRow(
                    icon: Icons.face_retouching_natural,
                    label: MatchDialogStrings.confidence((confidence * 100).round()),
                    valueColor: FaceEmbeddingCodec.meetsMinMatchConfidence(confidence)
                        ? Colors.green.shade700
                        : scheme.onSurfaceVariant,
                    valueWeight: FontWeight.w600,
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: (hasActive ? Colors.orange : Colors.green)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (hasActive ? Colors.orange : Colors.green)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasActive ? Icons.login : Icons.how_to_reg,
                        color: hasActive ? Colors.orange.shade800 : Colors.green.shade800,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasActive
                              ? MatchDialogStrings.statusCheckedIn
                              : MatchDialogStrings.statusNotCheckedIn,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: hasActive ? Colors.orange.shade900 : Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(MatchDialogStrings.dismiss),
          ),
          if (!hasActive)
            FilledButton(
              onPressed: attendanceBusy
                  ? null
                  : () async {
                      setDialogState(() => attendanceBusy = true);
                      final photoPath = await onCaptureAttendancePhoto?.call();
                      final result = await ref
                          .read(attendanceRepositoryProvider)
                          .checkIn(employee, photoPath: photoPath);
                      if (!ctx.mounted) return;
                      result.fold(
                        (f) {
                          setDialogState(() => attendanceBusy = false);
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text(f.message)));
                        },
                        (_) {
                          ref.invalidate(attendanceLogsProvider);
                          ref.invalidate(activeCheckInsTodayProvider);
                          Navigator.pop(ctx);
                          _showSuccess(ctx, MatchDialogStrings.checkInRecorded);
                        },
                      );
                    },
              child: attendanceBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(MatchDialogStrings.checkIn),
            ),
          if (hasActive)
            FilledButton(
              onPressed: attendanceBusy
                  ? null
                  : () async {
                      setDialogState(() => attendanceBusy = true);
                      final photoPath = await onCaptureAttendancePhoto?.call();
                      final result = await ref
                          .read(attendanceRepositoryProvider)
                          .checkOut(employee, photoPath: photoPath);
                      if (!ctx.mounted) return;
                      result.fold(
                        (f) {
                          setDialogState(() => attendanceBusy = false);
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text(f.message)));
                        },
                        (_) {
                          ref.invalidate(attendanceLogsProvider);
                          ref.invalidate(activeCheckInsTodayProvider);
                          Navigator.pop(ctx);
                          _showSuccess(ctx, MatchDialogStrings.checkOutRecorded);
                        },
                      );
                    },
              child: attendanceBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(MatchDialogStrings.checkOut),
            ),
        ],
      ),
      );
    },
  );
}

class _EmployeeMatchPhoto extends StatelessWidget {
  const _EmployeeMatchPhoto({required this.imageUrl});

  final String imageUrl;

  static const double _size = 160;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          imageUrl,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: SizedBox(
              width: _size,
              height: _size,
              child: Icon(Icons.person, size: _size * 0.4, color: scheme.outline),
            ),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: _size,
              height: _size,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: scheme.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MatchDetailRow extends StatelessWidget {
  const _MatchDetailRow({
    required this.icon,
    required this.label,
    this.valueColor,
    this.valueWeight,
  });

  final IconData icon;
  final String label;
  final Color? valueColor;
  final FontWeight? valueWeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: valueColor ?? scheme.onSurface,
                  fontWeight: valueWeight ?? FontWeight.w500,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

void _showSuccess(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
      title: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(AppStrings.ok),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/widgets/glass_panel.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/employee_match_dialog.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/kiosk_pin_pad.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

/// PIN-based attendance at the kiosk (no portal login).
class KioskPinAttendancePanel extends ConsumerStatefulWidget {
  const KioskPinAttendancePanel({super.key, required this.onOpenLogin});

  final VoidCallback onOpenLogin;

  @override
  ConsumerState<KioskPinAttendancePanel> createState() =>
      _KioskPinAttendancePanelState();
}

class _KioskPinAttendancePanelState extends ConsumerState<KioskPinAttendancePanel> {
  String _pin = '';
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_pin.length < 4) {
      setState(() => _error = KioskPinStrings.pinTooShort);
      return;
    }

    final config = ref.read(kioskConfigProvider).valueOrNull;
    final adminPin = config?.adminPin?.trim();
    if (adminPin != null && adminPin.isNotEmpty && _pin == adminPin) {
      setState(() => _error = KioskPinStrings.adminUseLogin);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final list = await ref.read(employeesListProvider.future);
    Employee? employee;
    for (final e in list) {
      if (e.pin.trim() == _pin) {
        employee = e;
        break;
      }
    }

    if (!mounted) return;
    if (employee == null) {
      setState(() {
        _submitting = false;
        _error = KioskPinStrings.employeeNotFound;
      });
      return;
    }

    final activeResult =
        await ref.read(attendanceRepositoryProvider).getActiveCheckIn(employee.id);
    final activeLog = activeResult.fold((_) => null, (log) => log);

    if (!mounted) return;
    setState(() => _submitting = false);
    _pin = '';
    await showEmployeeMatchDialog(
      context: context,
      ref: ref,
      employee: employee,
      activeLog: activeLog,
    );
  }

  void _tapDigit(String d) {
    if (_submitting || _pin.length >= 6) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassPanel(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.pin_outlined, size: 48, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  KioskSidebarStrings.pinAttendance,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  KioskPinStrings.pinAttendanceHint,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Text(
                  _pin.isEmpty ? '••••' : '•' * _pin.length,
                  textAlign: TextAlign.center,
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 12,
                    color: scheme.primary,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                KioskPinPad(onDigit: _tapDigit, onBackspace: _backspace),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(KioskPinStrings.markAttendance, style: textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _submitting ? null : widget.onOpenLogin,
                  child: Text(KioskSidebarStrings.loginWithPin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

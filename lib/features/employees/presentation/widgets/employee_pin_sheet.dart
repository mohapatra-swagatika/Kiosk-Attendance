import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

Future<void> showEmployeePinSheet({
  required BuildContext context,
  required Employee employee,
}) {
  final pin = employee.pin.trim().isEmpty
      ? EmployeePinStrings.noPin
      : employee.pin.trim();

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final scheme = theme.colorScheme;
      final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;

      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  EmployeePinStrings.sheetTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  EmployeePinStrings.subtitle(
                    name: employee.name,
                    id: employee.id,
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: 'Employee PIN $pin',
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SelectableText(
                      pin,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 52,
                        letterSpacing: 10,
                        height: 1.1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  EmployeePinStrings.hint,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (pin != EmployeePinStrings.noPin)
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pin));
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text(EmployeePinStrings.copied)),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text(EmployeePinStrings.copyButton),
                  ),
                if (pin != EmployeePinStrings.noPin) const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text(AppStrings.dismiss),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

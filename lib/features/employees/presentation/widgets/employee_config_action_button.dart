import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/app/theme/app_button_styles.dart';

/// Shared tonal action for Face / PIN configuration on employee details.
class EmployeeConfigActionButton extends StatelessWidget {
  const EmployeeConfigActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  static ButtonStyle get _style => AppButtonStyles.filledStyle(
        textStyle: AppButtonStyles.labelCompact,
      ).copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        visualDensity: VisualDensity.standard,
      );

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      style: _style,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

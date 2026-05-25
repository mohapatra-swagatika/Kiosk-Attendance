import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';

Future<void> showNoEmployeeDialog(
  BuildContext context, {
  required String reason,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.person_off, color: Colors.redAccent, size: 56),
      title: const Text(KioskStrings.noEmployeeFoundTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reason != KioskStrings.noEmployeeFoundTitle &&
              reason != KioskStrings.unknownFace) ...[
            Text(reason, textAlign: TextAlign.center),
            const SizedBox(height: 12),
          ],
          const Text(
            KioskStrings.noEmployeeFoundHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(AppStrings.ok),
        ),
      ],
    ),
  );
}

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';

/// Left-side thumbnail from kiosk/portal attendance capture.
class AttendanceRecordPhotoThumb extends StatelessWidget {
  const AttendanceRecordPhotoThumb({
    super.key,
    required this.log,
    this.size = 52,
  });

  final AttendanceLog log;
  final double size;

  String? get _path {
    if (log.isActiveCheckIn) return log.checkInPhotoPath;
    return log.checkOutPhotoPath ?? log.checkInPhotoPath;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = _path;
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(scheme),
        ),
      );
    }
    return _placeholder(scheme);
  }

  Widget _placeholder(ColorScheme scheme) {
    return SizedBox(
      width: size,
      height: size,
      child: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(Icons.person, color: scheme.outline, size: size * 0.45),
      ),
    );
  }
}

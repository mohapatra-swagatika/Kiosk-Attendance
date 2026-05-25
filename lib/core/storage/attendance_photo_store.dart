import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Persists attendance selfie JPEGs under app documents (offline-first).
class AttendancePhotoStore {
  const AttendancePhotoStore();

  static const _uuid = Uuid();

  Future<String> saveFromFile({
    required File source,
    required String employeeId,
    required bool isCheckOut,
  }) async {
    final dir = await _photosDir();
    final name =
        '${employeeId}_${isCheckOut ? 'out' : 'in'}_${_uuid.v4()}.jpg';
    final dest = File('${dir.path}/$name');
    await source.copy(dest.path);
    return dest.path;
  }

  Future<Directory> _photosDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/attendance_photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

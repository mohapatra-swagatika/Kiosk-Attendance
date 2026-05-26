import 'dart:convert';
import 'dart:io';

/// Encodes attendance selfies as a data-URI for the bulk events API.
class KioskEventSelfieEncoder {
  const KioskEventSelfieEncoder();

  static const String dataUriPrefix = 'data:image/png;base64,';

  Future<String> encodeFile(String? photoPath) async {
    if (photoPath == null || photoPath.trim().isEmpty) return '';
    final trimmed = photoPath.trim();
    if (trimmed.startsWith('data:image')) return trimmed;

    final file = File(trimmed);
    if (!await file.exists()) return '';
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return '';
      return '$dataUriPrefix${base64Encode(bytes)}';
    } catch (_) {
      return '';
    }
  }
}

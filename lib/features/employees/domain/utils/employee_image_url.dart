/// Resolves employee photo URLs from snapshot (absolute or tenant-relative).
String resolveEmployeeImageUrl(String imageUrl, {String? apiBaseUrl}) {
  final url = imageUrl.trim();
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;

  final base = apiBaseUrl?.trim();
  if (base == null || base.isEmpty) return url;

  final root = base.replaceFirst(RegExp(r'^https?://'), '');
  final host = root.split('/').first;
  final origin = base.startsWith('http') ? base.split('/').take(3).join('/') : 'https://$host';
  final path = url.startsWith('/') ? url : '/$url';
  return '$origin$path';
}

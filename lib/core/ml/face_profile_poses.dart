/// Canonical pose keys stored in on-device face profiles (v6+).
abstract final class FaceProfilePoses {
  static const String straight = 'straight';
  static const String left = 'left';
  static const String right = 'right';
  static const String up = 'up';
  static const String down = 'down';
  static const String combined = 'combined';

  /// Required for new enrollments (v6 minimum).
  static const List<String> required = [straight, left, right, combined];

  /// All pose averages used at match time (optional keys skipped if missing).
  static const List<String> matchKeys = [
    straight,
    left,
    right,
    up,
    down,
    combined,
  ];

  static const String templatesKey = 'templates';
}

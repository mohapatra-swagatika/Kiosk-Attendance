/// Build / deployment environment (set via `--dart-define=APP_ENV=...`).
enum AppEnvironment {
  dev,
  staging,
  prod;

  static const String _defineKey = 'APP_ENV';

  /// Compile-time environment from `dart-define` (default: [AppEnvironment.dev]).
  static AppEnvironment get current {
    const raw = String.fromEnvironment(_defineKey, defaultValue: 'dev');
    return fromName(raw);
  }

  static AppEnvironment fromName(String value) {
    switch (value.trim().toLowerCase()) {
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'dev':
      case 'development':
      default:
        return AppEnvironment.dev;
    }
  }

  bool get isProd => this == AppEnvironment.prod;

  bool get isDev => this == AppEnvironment.dev;
}

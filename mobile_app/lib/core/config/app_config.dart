class AppConfig {
  AppConfig._();

  /// Hosted backend (Render). Override at build time with --dart-define if you
  /// ever need to point at a local server instead:
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api --dart-define=SOCKET_URL=http://10.0.2.2:5000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://transportplatform.onrender.com/api',
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://transportplatform.onrender.com',
  );

  // Section 6.2 defaults, overridden by /api/settings at runtime.
  static const int defaultReturnLoadRadiusKm = 100;
  static const int defaultReturnLoadWindowDays = 3;
}

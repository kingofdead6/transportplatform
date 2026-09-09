class AppConfig {
  AppConfig._();

  /// Point this at your running backend. Use 10.0.2.2 for Android emulator -> localhost,
  /// or your machine's LAN IP when testing on a physical device.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  // Section 6.2 defaults, overridden by /api/settings at runtime.
  static const int defaultReturnLoadRadiusKm = 100;
  static const int defaultReturnLoadWindowDays = 3;
}

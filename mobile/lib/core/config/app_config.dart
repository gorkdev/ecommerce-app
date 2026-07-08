import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Override the API host without touching source:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api`
abstract final class AppConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get apiBaseUrl =>
      _apiBaseUrlOverride.isNotEmpty ? _apiBaseUrlOverride : _defaultApiBaseUrl;

  /// Emulators cannot reach the developer machine through `localhost`: the
  /// Android emulator maps the host to the special address 10.0.2.2, while the
  /// iOS simulator shares the host's loopback interface.
  static String get _defaultApiBaseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:3000/api',
      _ => 'http://localhost:3000/api',
    };
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

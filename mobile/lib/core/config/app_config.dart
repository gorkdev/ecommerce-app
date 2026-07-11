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

  /// Media URLs (MinIO) are stored with the host the *API* saw — usually
  /// `localhost:9000` in development — which an emulator cannot reach. Swap a
  /// loopback host for the API's host (10.0.2.2 on the Android emulator),
  /// keeping the media server's own port. Anything already non-loopback (a
  /// real bucket, a CDN) passes through untouched.
  static String resolveMediaUrl(String url) {
    final Uri? media = Uri.tryParse(url);
    if (media == null || !media.hasAuthority) return url;
    if (media.host != 'localhost' && media.host != '127.0.0.1') return url;

    final String apiHost = Uri.parse(apiBaseUrl).host;
    if (apiHost == media.host) return url;
    return media.replace(host: apiHost).toString();
  }

  /// Stripe *publishable* key (`pk_test_...` / `pk_live_...`). Not a secret,
  /// but environment-specific, so it rides in the same way as the API host:
  /// `flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...`
  /// Left empty the app still runs — checkout then fails with a clear message
  /// instead of a native crash deep inside the payment sheet.
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
  );

  /// Shown as the merchant name on Stripe's payment sheet.
  static const String merchantDisplayName = 'Ecommerce App';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

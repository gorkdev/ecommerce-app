import 'package:ecommerce_app/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('AppConfig.resolveMediaUrl', () {
    test('rewrites a loopback host to the API host on the emulator', () {
      // On Android the API host is the emulator's host alias 10.0.2.2.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(
        AppConfig.resolveMediaUrl(
          'http://localhost:9000/product-images/a.png',
        ),
        'http://10.0.2.2:9000/product-images/a.png',
      );
      expect(
        AppConfig.resolveMediaUrl('http://127.0.0.1:9000/b/k.png'),
        'http://10.0.2.2:9000/b/k.png',
      );
    });

    test('leaves the URL alone when the API itself is on localhost', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(
        AppConfig.resolveMediaUrl('http://localhost:9000/a.png'),
        'http://localhost:9000/a.png',
      );
    });

    test('never touches a real, non-loopback media host', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(
        AppConfig.resolveMediaUrl('https://cdn.example.com/a.png'),
        'https://cdn.example.com/a.png',
      );
    });

    test('passes through values that are not absolute URLs', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(AppConfig.resolveMediaUrl('/relative/a.png'), '/relative/a.png');
      expect(AppConfig.resolveMediaUrl('not a url'), 'not a url');
    });
  });
}

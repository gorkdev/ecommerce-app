import 'dart:ui';

import 'package:ecommerce_app/core/l10n/locale_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> build([
    Map<String, Object> stored = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(stored);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      // Mirrors main.dart: automatic provider retry stays off in tests.
      retry: (int retryCount, Object error) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('follows the device when nothing is stored', () async {
    final ProviderContainer container = await build();

    expect(container.read(localeControllerProvider), isNull);
  });

  test('restores the stored choice', () async {
    final ProviderContainer container = await build(<String, Object>{
      'locale': 'tr',
    });

    expect(container.read(localeControllerProvider), const Locale('tr'));
  });

  test('set applies and persists the language code', () async {
    final ProviderContainer container = await build();

    await container
        .read(localeControllerProvider.notifier)
        .set(const Locale('tr'));

    expect(container.read(localeControllerProvider), const Locale('tr'));
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('locale'), 'tr');
  });

  test('set(null) reverts to the device locale and clears the store', () async {
    final ProviderContainer container = await build(<String, Object>{
      'locale': 'tr',
    });

    await container.read(localeControllerProvider.notifier).set(null);

    expect(container.read(localeControllerProvider), isNull);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('locale'), isNull);
  });
}

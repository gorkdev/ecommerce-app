import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden with the real instance in `main` (and in every test scope).
/// Reading it without an override is a wiring bug, not a runtime condition,
/// hence the throw instead of a lazy fallback.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (_) => throw UnimplementedError(
        'sharedPreferencesProvider must be overridden with a real instance',
      ),
    );

/// The user's explicit language choice; `null` means "follow the device".
///
/// Only the language code is stored — the app localizes by language, not by
/// region, so `Locale('tr')` is as specific as a choice ever gets.
class LocaleController extends Notifier<Locale?> {
  static const String _prefsKey = 'locale';

  @override
  Locale? build() {
    final String? code = ref
        .watch(sharedPreferencesProvider)
        .getString(_prefsKey);
    return code == null ? null : Locale(code);
  }

  /// Persists [locale] and applies it immediately; `null` clears the choice
  /// and reverts to the device locale.
  Future<void> set(Locale? locale) async {
    state = locale;
    final SharedPreferences preferences = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await preferences.remove(_prefsKey);
    } else {
      await preferences.setString(_prefsKey, locale.languageCode);
    }
  }
}

final NotifierProvider<LocaleController, Locale?> localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

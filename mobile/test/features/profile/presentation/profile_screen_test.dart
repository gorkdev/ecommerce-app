import 'package:ecommerce_app/core/l10n/locale_controller.dart';
import 'package:ecommerce_app/core/storage/token_storage.dart';
import 'package:ecommerce_app/features/auth/data/auth_repository.dart';
import 'package:ecommerce_app/features/auth/domain/auth_user.dart';
import 'package:ecommerce_app/features/profile/presentation/profile_screen.dart';
import 'package:ecommerce_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/in_memory_token_storage.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const AuthUser _ada = AuthUser(
  id: 'usr_1',
  email: 'ada@example.com',
  name: 'Ada Lovelace',
  role: UserRole.customer,
);

/// Mirrors the real [EcommerceApp]: the locale follows the controller, so a
/// language switch re-renders the tree — which is exactly what the picker
/// tests assert.
class _LocaleAwareApp extends ConsumerWidget {
  const _LocaleAwareApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      locale: ref.watch(localeControllerProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProfileScreen(),
    );
  }
}

void main() {
  late MockAuthRepository repository;
  late InMemoryTokenStorage storage;

  setUp(() {
    repository = MockAuthRepository();
    // Stored tokens make the real controller restore the session via me().
    storage = InMemoryTokenStorage(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    when(() => repository.me()).thenAnswer((_) async => _ada);
    when(() => repository.logout(any())).thenAnswer((_) async {});
  });

  Future<SharedPreferences> pumpProfile(
    WidgetTester tester, {
    Map<String, Object> stored = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry stays off in tests.
        retry: (int retryCount, Object error) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          tokenStorageProvider.overrideWithValue(storage),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const _LocaleAwareApp(),
      ),
    );
    await tester.pumpAndSettle();
    return preferences;
  }

  testWidgets('shows the signed-in user and the section doors', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('A'), findsOneWidget); // avatar initial
    expect(find.text('My orders'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Addresses'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
  });

  testWidgets('sign out revokes the token and clears the session', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    verify(() => repository.logout('refresh-1')).called(1);
    expect(storage.accessToken, isNull);
    expect(find.text('Ada Lovelace'), findsNothing);
  });

  testWidgets('a stored language renders from the first frame', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester, stored: <String, Object>{'locale': 'tr'});

    expect(find.text('Siparişlerim'), findsOneWidget);
    expect(find.text('Çıkış yap'), findsOneWidget);
    expect(find.text('Türkçe'), findsOneWidget); // the tile's subtitle
  });

  testWidgets('picking a language re-renders the app and persists', (
    WidgetTester tester,
  ) async {
    final SharedPreferences preferences = await pumpProfile(tester);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    // The sheet offers the system default and both languages.
    expect(find.text('System default'), findsNWidgets(2)); // tile + sheet
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('Türkçe'));
    await tester.pumpAndSettle();

    expect(find.text('Çıkış yap'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    expect(preferences.getString('locale'), 'tr');
  });
}

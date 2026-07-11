import 'package:ecommerce_app/core/storage/token_storage.dart';
import 'package:ecommerce_app/features/auth/data/auth_repository.dart';
import 'package:ecommerce_app/features/auth/domain/auth_user.dart';
import 'package:ecommerce_app/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/in_memory_token_storage.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const AuthUser _ada = AuthUser(
  id: 'usr_1',
  email: 'ada@example.com',
  name: 'Ada Lovelace',
  role: UserRole.customer,
);

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

  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry stays off in tests.
        retry: (int retryCount, Object error) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          tokenStorageProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
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
}

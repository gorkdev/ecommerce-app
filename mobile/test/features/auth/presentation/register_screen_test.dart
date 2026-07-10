import 'dart:async';

import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/core/storage/token_storage.dart';
import 'package:ecommerce_app/features/auth/data/auth_repository.dart';
import 'package:ecommerce_app/features/auth/domain/auth_session.dart';
import 'package:ecommerce_app/features/auth/domain/auth_user.dart';
import 'package:ecommerce_app/features/auth/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/in_memory_token_storage.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const AuthSession _session = AuthSession(
  user: AuthUser(
    id: 'usr_1',
    email: 'customer@example.com',
    name: 'Ada Lovelace',
    role: UserRole.customer,
  ),
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
);

void main() {
  late MockAuthRepository repository;
  late InMemoryTokenStorage storage;

  setUp(() {
    repository = MockAuthRepository();
    storage = InMemoryTokenStorage();
  });

  Future<void> pumpRegisterScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          tokenStorageProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pump();
  }

  Finder nameField() => find.byType(TextFormField).at(0);
  Finder emailField() => find.byType(TextFormField).at(1);
  Finder passwordField() => find.byType(TextFormField).at(2);
  Finder submitButton() => find.widgetWithText(FilledButton, 'Create account');

  Future<void> fill(
    WidgetTester tester, {
    String name = 'Ada Lovelace',
    String email = 'customer@example.com',
    String password = 'hunter2!!',
  }) async {
    await tester.enterText(nameField(), name);
    await tester.enterText(emailField(), email);
    await tester.enterText(passwordField(), password);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(submitButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('rejects a too-short name before hitting the network', (
    WidgetTester tester,
  ) async {
    await pumpRegisterScreen(tester);

    await fill(tester, name: 'A');
    await submit(tester);

    expect(find.text('Use at least 2 characters.'), findsOneWidget);
    verifyZeroInteractions(repository);
  });

  testWidgets('enforces the registration password rules, unlike login', (
    WidgetTester tester,
  ) async {
    await pumpRegisterScreen(tester);

    await fill(tester, password: 'short7!');
    await submit(tester);

    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    verifyZeroInteractions(repository);
  });

  testWidgets('submits trimmed name and email and stores the tokens', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) async => _session);

    await pumpRegisterScreen(tester);

    await fill(
      tester,
      name: '  Ada Lovelace ',
      email: ' customer@example.com  ',
    );
    await submit(tester);

    verify(
      () => repository.register(
        email: 'customer@example.com',
        password: 'hunter2!!',
        name: 'Ada Lovelace',
      ),
    ).called(1);
    expect(storage.accessToken, 'access-1');
    expect(storage.refreshToken, 'refresh-1');
  });

  testWidgets('surfaces a duplicate email exactly as the server reports it', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        name: any(named: 'name'),
      ),
    ).thenThrow(const ApiStatusException(409, 'Email is already registered'));

    await pumpRegisterScreen(tester);

    await fill(tester);
    await submit(tester);

    expect(find.text('Email is already registered'), findsOneWidget);
    // The form must come back to life so the user can try another address.
    expect(tester.widget<FilledButton>(submitButton()).onPressed, isNotNull);
    expect(storage.accessToken, isNull);
  });

  testWidgets('blocks a second submit while the first is in flight', (
    WidgetTester tester,
  ) async {
    final Completer<AuthSession> pending = Completer<AuthSession>();
    when(
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) => pending.future);

    await pumpRegisterScreen(tester);

    await fill(tester);
    await tester.tap(submitButton());
    await tester.pump();

    // A spinner replaced the label, and the button is disabled.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    pending.complete(_session);
    await tester.pumpAndSettle();

    verify(
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        name: any(named: 'name'),
      ),
    ).called(1);
  });
}

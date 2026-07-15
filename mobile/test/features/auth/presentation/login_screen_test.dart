import 'dart:async';

import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/core/storage/token_storage.dart';
import 'package:ecommerce_app/features/auth/data/auth_repository.dart';
import 'package:ecommerce_app/features/auth/domain/auth_session.dart';
import 'package:ecommerce_app/features/auth/domain/auth_user.dart';
import 'package:ecommerce_app/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/in_memory_token_storage.dart';
import '../../../support/test_app.dart';

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

  Future<void> pumpLoginScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          tokenStorageProvider.overrideWithValue(storage),
        ],
        child: testApp(home: const LoginScreen()),
      ),
    );
    await tester.pump();
  }

  Finder emailField() => find.byType(TextFormField).first;
  Finder passwordField() => find.byType(TextFormField).last;
  Finder submitButton() => find.widgetWithText(FilledButton, 'Sign in');

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(submitButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('rejects a malformed email before hitting the network', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    await tester.enterText(emailField(), 'not-an-email');
    await tester.enterText(passwordField(), 'hunter2!!');
    await submit(tester);

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('requires a password', (WidgetTester tester) async {
    await pumpLoginScreen(tester);

    await tester.enterText(emailField(), 'customer@example.com');
    await submit(tester);

    expect(find.text('Enter your password.'), findsOneWidget);
    verifyZeroInteractions(repository);
  });

  testWidgets('submits trimmed credentials and stores the tokens', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => _session);

    await pumpLoginScreen(tester);

    await tester.enterText(emailField(), '  customer@example.com ');
    await tester.enterText(passwordField(), 'hunter2!!');
    await submit(tester);

    verify(
      () => repository.login(
        email: 'customer@example.com',
        password: 'hunter2!!',
      ),
    ).called(1);
    expect(storage.accessToken, 'access-1');
    expect(storage.refreshToken, 'refresh-1');
  });

  testWidgets('shows the server message when the credentials are wrong', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const ApiStatusException(401, 'Invalid credentials'));

    await pumpLoginScreen(tester);

    await tester.enterText(emailField(), 'customer@example.com');
    await tester.enterText(passwordField(), 'wrong-password');
    await submit(tester);

    expect(find.text('Invalid credentials'), findsOneWidget);
    // The form must come back to life so the user can try again.
    expect(tester.widget<FilledButton>(submitButton()).onPressed, isNotNull);
  });

  testWidgets('reports an offline API without leaking Dio internals', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const NetworkException());

    await pumpLoginScreen(tester);

    await tester.enterText(emailField(), 'customer@example.com');
    await tester.enterText(passwordField(), 'hunter2!!');
    await submit(tester);

    expect(find.text('No connection to the server.'), findsOneWidget);
  });

  testWidgets('the password is obscured until the reveal button is tapped', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isTrue,
    );

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isFalse,
    );
  });

  testWidgets('blocks a second submit while the first is in flight', (
    WidgetTester tester,
  ) async {
    final Completer<AuthSession> pending = Completer<AuthSession>();
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => pending.future);

    await pumpLoginScreen(tester);

    await tester.enterText(emailField(), 'customer@example.com');
    await tester.enterText(passwordField(), 'hunter2!!');
    await tester.tap(submitButton());
    await tester.pump();

    // A spinner replaced the label, and the button is disabled. The register
    // link is a FilledButton.tonal too, so anchor on the spinner's ancestor.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.byType(CircularProgressIndicator),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );

    pending.complete(_session);
    await tester.pumpAndSettle();

    verify(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).called(1);
  });
}

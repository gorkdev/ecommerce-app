import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/core/network/session_expiry.dart';
import 'package:ecommerce_app/core/storage/token_storage.dart';
import 'package:ecommerce_app/features/auth/application/auth_controller.dart';
import 'package:ecommerce_app/features/auth/data/auth_repository.dart';
import 'package:ecommerce_app/features/auth/domain/auth_session.dart';
import 'package:ecommerce_app/features/auth/domain/auth_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/in_memory_token_storage.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const AuthUser _ada = AuthUser(
  id: 'usr_1',
  email: 'customer@example.com',
  name: 'Ada Lovelace',
  role: UserRole.customer,
);

const AuthSession _session = AuthSession(
  user: _ada,
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
);

void main() {
  late MockAuthRepository repository;
  late InMemoryTokenStorage storage;

  ProviderContainer makeContainer() {
    // `Override` is not exported by flutter_riverpod 3, so the list stays raw.
    final ProviderContainer container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    repository = MockAuthRepository();
    storage = InMemoryTokenStorage();
  });

  group('session restore', () {
    test('stays signed out when no access token is stored', () async {
      final ProviderContainer container = makeContainer();

      expect(await container.read(authControllerProvider.future), isNull);
      verifyNever(() => repository.me());
    });

    test('verifies a stored token against the server', () async {
      storage.accessToken = 'access-1';
      storage.refreshToken = 'refresh-1';
      when(() => repository.me()).thenAnswer((_) async => _ada);

      final ProviderContainer container = makeContainer();

      expect(await container.read(authControllerProvider.future), _ada);
      verify(() => repository.me()).called(1);
    });

    test('wipes tokens the server no longer accepts', () async {
      // The interceptor already tried (and failed) to refresh by this point.
      storage.accessToken = 'stale';
      storage.refreshToken = 'stale';
      when(
        () => repository.me(),
      ).thenThrow(const ApiStatusException(401, 'Unauthorized'));

      final ProviderContainer container = makeContainer();

      expect(await container.read(authControllerProvider.future), isNull);
      expect(storage.clearCount, 1);
      expect(storage.accessToken, isNull);
    });

    test(
      'keeps the credentials when the profile call fails transiently',
      () async {
        // Launching offline must not destroy a perfectly good session.
        storage.accessToken = 'access-1';
        storage.refreshToken = 'refresh-1';
        when(() => repository.me()).thenThrow(const NetworkException());

        final ProviderContainer container = makeContainer();

        expect(await container.read(authControllerProvider.future), isNull);
        expect(storage.clearCount, 0);
        expect(storage.accessToken, 'access-1');
      },
    );
  });

  group('login', () {
    test('persists the token pair and publishes the user', () async {
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _session);

      final ProviderContainer container = makeContainer();
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'customer@example.com', password: 'hunter2!!');

      expect(container.read(authControllerProvider).value, _ada);
      expect(storage.accessToken, 'access-1');
      expect(storage.refreshToken, 'refresh-1');
      expect(storage.saveCount, 1);
    });

    test(
      'rethrows so the form can render the failure, and stays signed out',
      () async {
        when(
          () => repository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const ApiStatusException(401, 'Invalid credentials'));

        final ProviderContainer container = makeContainer();
        await container.read(authControllerProvider.future);

        await expectLater(
          container
              .read(authControllerProvider.notifier)
              .login(email: 'customer@example.com', password: 'wrong'),
          throwsA(isA<ApiStatusException>()),
        );

        // A failed sign-in is a form error, never a broken session.
        final AsyncValue<AuthUser?> state = container.read(
          authControllerProvider,
        );
        expect(state.hasError, isFalse);
        expect(state.value, isNull);
        expect(storage.saveCount, 0);
      },
    );
  });

  group('register', () {
    test('persists the token pair and publishes the user', () async {
      when(
        () => repository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => _session);

      final ProviderContainer container = makeContainer();
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .register(
            email: 'customer@example.com',
            password: 'hunter2!!',
            name: 'Ada Lovelace',
          );

      expect(container.read(authControllerProvider).value, _ada);
      expect(storage.accessToken, 'access-1');
    });
  });

  group('logout', () {
    test('revokes the refresh token, clears storage and signs out', () async {
      storage.accessToken = 'access-1';
      storage.refreshToken = 'refresh-1';
      when(() => repository.me()).thenAnswer((_) async => _ada);
      when(() => repository.logout(any())).thenAnswer((_) async {});

      final ProviderContainer container = makeContainer();
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).logout();

      verify(() => repository.logout('refresh-1')).called(1);
      expect(storage.clearCount, 1);
      expect(container.read(authControllerProvider).value, isNull);
    });

    test(
      'still clears local credentials when the revocation call fails',
      () async {
        storage.accessToken = 'access-1';
        storage.refreshToken = 'refresh-1';
        when(() => repository.me()).thenAnswer((_) async => _ada);
        when(
          () => repository.logout(any()),
        ).thenThrow(const NetworkException());

        final ProviderContainer container = makeContainer();
        await container.read(authControllerProvider.future);

        await container.read(authControllerProvider.notifier).logout();

        expect(storage.accessToken, isNull);
        expect(container.read(authControllerProvider).value, isNull);
      },
    );

    test('skips the revocation call when there is nothing to revoke', () async {
      final ProviderContainer container = makeContainer();
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).logout();

      verifyNever(() => repository.logout(any()));
      expect(container.read(authControllerProvider).value, isNull);
    });
  });

  group('session expiry', () {
    test(
      'signs the user out when the network layer gives up refreshing',
      () async {
        storage.accessToken = 'access-1';
        when(() => repository.me()).thenAnswer((_) async => _ada);

        final ProviderContainer container = makeContainer();
        expect(await container.read(authControllerProvider.future), _ada);

        container.read(sessionExpiryProvider).notifyExpired();

        expect(container.read(authControllerProvider).value, isNull);
      },
    );

    test('is a no-op when the user is already signed out', () async {
      final ProviderContainer container = makeContainer();
      await container.read(authControllerProvider.future);

      container.read(sessionExpiryProvider).notifyExpired();

      expect(container.read(authControllerProvider).value, isNull);
      expect(container.read(authControllerProvider).hasError, isFalse);
    });
  });
}

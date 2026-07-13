import 'dart:async';
import 'dart:ui';

import 'package:ecommerce_app/core/l10n/locale_controller.dart';
import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/core/push/push_messaging_service.dart';
import 'package:ecommerce_app/core/storage/token_storage.dart';
import 'package:ecommerce_app/features/auth/application/auth_controller.dart';
import 'package:ecommerce_app/features/auth/data/auth_repository.dart';
import 'package:ecommerce_app/features/auth/domain/auth_user.dart';
import 'package:ecommerce_app/features/notifications/application/push_registrar.dart';
import 'package:ecommerce_app/features/notifications/data/notifications_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/in_memory_token_storage.dart';

class MockPushMessagingService extends Mock implements PushMessagingService {}

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

const AuthUser _user = AuthUser(
  id: 'usr_1',
  email: 'customer@example.com',
  name: 'Ada Lovelace',
  role: UserRole.customer,
);

/// Lets the registrar's fire-and-forget futures run to completion.
Future<void> _settle() async {
  for (int i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPushMessagingService service;
  late MockNotificationsRepository notifications;
  late MockAuthRepository authRepository;
  late StreamController<String> tokenRefresh;
  late StreamController<PushMessage> opened;
  late StreamController<PushMessage> foreground;

  setUp(() {
    service = MockPushMessagingService();
    tokenRefresh = StreamController<String>.broadcast();
    opened = StreamController<PushMessage>.broadcast();
    foreground = StreamController<PushMessage>.broadcast();
    when(() => service.initialize()).thenAnswer((_) async => true);
    when(() => service.getToken()).thenAnswer((_) async => 'fcm-token-1');
    when(() => service.tokenRefreshStream())
        .thenAnswer((_) => tokenRefresh.stream);
    when(() => service.openedMessages()).thenAnswer((_) => opened.stream);
    when(() => service.foregroundMessages())
        .thenAnswer((_) => foreground.stream);
    when(() => service.initialMessage()).thenAnswer((_) async => null);

    notifications = MockNotificationsRepository();
    when(
      () => notifications.registerDeviceToken(
        token: any(named: 'token'),
        platform: any(named: 'platform'),
        locale: any(named: 'locale'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notifications.removeDeviceToken(any()),
    ).thenAnswer((_) async {});

    authRepository = MockAuthRepository();
    when(() => authRepository.me()).thenAnswer((_) async => _user);
  });

  tearDown(() async {
    await tokenRefresh.close();
    await opened.close();
    await foreground.close();
  });

  Future<ProviderContainer> build({
    bool signedIn = true,
    Map<String, Object> prefs = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final InMemoryTokenStorage storage = InMemoryTokenStorage(
      accessToken: signedIn ? 'access-1' : null,
      refreshToken: signedIn ? 'refresh-1' : null,
    );
    final ProviderContainer container = ProviderContainer(
      // Mirrors main.dart: automatic provider retry stays off in tests.
      retry: (int retryCount, Object error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        pushMessagingServiceProvider.overrideWithValue(service),
        notificationsRepositoryProvider.overrideWithValue(notifications),
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
    );
    addTearDown(container.dispose);

    container.read(pushRegistrarProvider); // wake the registrar
    await container.read(authControllerProvider.future); // restore session
    await _settle();
    return container;
  }

  test('registers the device once the stored session is restored', () async {
    await build(prefs: <String, Object>{'locale': 'tr'});

    verify(
      () => notifications.registerDeviceToken(
        token: 'fcm-token-1',
        platform: 'android',
        locale: 'tr',
      ),
    ).called(1);
  });

  test('falls back to the device language when none is stored', () async {
    await build();

    verify(
      () => notifications.registerDeviceToken(
        token: 'fcm-token-1',
        platform: 'android',
        locale: PlatformDispatcher.instance.locale.languageCode,
      ),
    ).called(1);
  });

  test('does not register while signed out', () async {
    await build(signedIn: false);

    verifyNever(
      () => notifications.registerDeviceToken(
        token: any(named: 'token'),
        platform: any(named: 'platform'),
        locale: any(named: 'locale'),
      ),
    );
  });

  test('does not register when no token is available (permission denied)',
      () async {
    when(() => service.getToken()).thenAnswer((_) async => null);

    await build();

    verifyNever(
      () => notifications.registerDeviceToken(
        token: any(named: 'token'),
        platform: any(named: 'platform'),
        locale: any(named: 'locale'),
      ),
    );
  });

  test('stays inert when Firebase is not configured', () async {
    when(() => service.initialize()).thenAnswer((_) async => false);
    // The real seam answers null for every token ask when unsupported.
    when(() => service.getToken()).thenAnswer((_) async => null);

    await build();

    // No message streams get wired, and nothing reaches the API.
    verifyNever(() => service.tokenRefreshStream());
    verifyNever(
      () => notifications.registerDeviceToken(
        token: any(named: 'token'),
        platform: any(named: 'platform'),
        locale: any(named: 'locale'),
      ),
    );
  });

  test('an FCM token rotation re-registers the fresh token', () async {
    await build();
    when(() => service.getToken()).thenAnswer((_) async => 'fcm-token-2');

    tokenRefresh.add('fcm-token-2');
    await _settle();

    verify(
      () => notifications.registerDeviceToken(
        token: 'fcm-token-2',
        platform: any(named: 'platform'),
        locale: any(named: 'locale'),
      ),
    ).called(1);
  });

  test('a language change re-registers in the new language', () async {
    final ProviderContainer container = await build();

    await container
        .read(localeControllerProvider.notifier)
        .set(const Locale('tr'));
    await _settle();

    verify(
      () => notifications.registerDeviceToken(
        token: 'fcm-token-1',
        platform: any(named: 'platform'),
        locale: 'tr',
      ),
    ).called(1);
  });

  test('unregisterDevice deletes the registered token exactly once',
      () async {
    final ProviderContainer container = await build();

    await container.read(pushRegistrarProvider.notifier).unregisterDevice();
    await container.read(pushRegistrarProvider.notifier).unregisterDevice();

    verify(() => notifications.removeDeviceToken('fcm-token-1')).called(1);
  });

  test('a failed registration is swallowed, not thrown', () async {
    when(
      () => notifications.registerDeviceToken(
        token: any(named: 'token'),
        platform: any(named: 'platform'),
        locale: any(named: 'locale'),
      ),
    ).thenThrow(const NetworkException());

    // Building (and thus registering) must not surface the error anywhere.
    await build();
  });

  test('a failed unregister still lets the sign-out proceed', () async {
    final ProviderContainer container = await build();
    when(
      () => notifications.removeDeviceToken(any()),
    ).thenThrow(const NetworkException());

    await container.read(pushRegistrarProvider.notifier).unregisterDevice();
  });
}

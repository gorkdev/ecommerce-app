import 'package:dio/dio.dart';
import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/core/network/auth_interceptor.dart';
import 'package:ecommerce_app/features/auth/data/auth_repository.dart';
import 'package:ecommerce_app/features/auth/domain/auth_session.dart';
import 'package:ecommerce_app/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_adapter.dart';

const Map<String, Object?> _user = <String, Object?>{
  'id': 'usr_1',
  'email': 'customer@example.com',
  'name': 'Ada Lovelace',
  'role': 'CUSTOMER',
};

({AuthRepository repository, FakeHttpAdapter adapter}) _build(
  FakeResponder responder,
) {
  final FakeHttpAdapter adapter = FakeHttpAdapter(responder);
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test',
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = adapter;
  return (repository: AuthRepository(dio), adapter: adapter);
}

void main() {
  group('AuthRepository.login', () {
    test('posts the credentials and parses the session', () async {
      final ({AuthRepository repository, FakeHttpAdapter adapter}) sut = _build(
        (_) => FakeHttpAdapter.json(200, <String, Object?>{
          'user': _user,
          'accessToken': 'access-1',
          'refreshToken': 'refresh-1',
        }),
      );

      final AuthSession session = await sut.repository.login(
        email: 'customer@example.com',
        password: 'hunter2!!',
      );

      expect(session.accessToken, 'access-1');
      expect(session.refreshToken, 'refresh-1');
      expect(session.user.id, 'usr_1');
      expect(session.user.role, UserRole.customer);

      final RequestOptions request = sut.adapter.requests.single;
      expect(request.path, '/auth/login');
      expect(request.method, 'POST');
      expect(request.data, <String, String>{
        'email': 'customer@example.com',
        'password': 'hunter2!!',
      });
    });

    test('opts out of the refresh flow', () async {
      // A 401 here means "wrong password", so the interceptor must not treat it
      // as an expired session.
      final ({AuthRepository repository, FakeHttpAdapter adapter}) sut = _build(
        (_) => FakeHttpAdapter.json(200, <String, Object?>{
          'user': _user,
          'accessToken': 'a',
          'refreshToken': 'r',
        }),
      );

      await sut.repository.login(email: 'a@b.co', password: 'x');

      expect(
        sut.adapter.requests.single.extra[AuthInterceptor.skipAuthFlag],
        isTrue,
      );
    });

    test(
      'turns a 401 into an ApiStatusException carrying the server message',
      () async {
        final ({AuthRepository repository, FakeHttpAdapter adapter}) sut =
            _build(
              (_) => FakeHttpAdapter.json(401, <String, Object?>{
                'statusCode': 401,
                'message': 'Invalid credentials',
                'error': 'Unauthorized',
              }),
            );

        await expectLater(
          sut.repository.login(email: 'a@b.co', password: 'wrong'),
          throwsA(
            isA<ApiStatusException>()
                .having(
                  (ApiStatusException e) => e.statusCode,
                  'statusCode',
                  401,
                )
                .having(
                  (ApiStatusException e) => e.message,
                  'message',
                  'Invalid credentials',
                ),
          ),
        );
      },
    );

    test('turns a dead connection into a NetworkException', () async {
      final ({AuthRepository repository, FakeHttpAdapter adapter}) sut = _build(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );

      await expectLater(
        sut.repository.login(email: 'a@b.co', password: 'x'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('rejects a 2xx with no body instead of crashing later', () async {
      final ({AuthRepository repository, FakeHttpAdapter adapter}) sut = _build(
        (_) => FakeHttpAdapter.noContent(),
      );

      await expectLater(
        sut.repository.login(email: 'a@b.co', password: 'x'),
        throwsA(isA<UnexpectedApiException>()),
      );
    });
  });

  group('AuthRepository.register', () {
    test('posts email, password and name', () async {
      final ({AuthRepository repository, FakeHttpAdapter adapter}) sut = _build(
        (_) => FakeHttpAdapter.json(201, <String, Object?>{
          'user': _user,
          'accessToken': 'a',
          'refreshToken': 'r',
        }),
      );

      await sut.repository.register(
        email: 'customer@example.com',
        password: 'hunter2!!',
        name: 'Ada Lovelace',
      );

      final RequestOptions request = sut.adapter.requests.single;
      expect(request.path, '/auth/register');
      expect(request.data, <String, String>{
        'email': 'customer@example.com',
        'password': 'hunter2!!',
        'name': 'Ada Lovelace',
      });
    });

    test('surfaces the first DTO validation message on a 400', () async {
      final ({AuthRepository repository, FakeHttpAdapter adapter}) sut = _build(
        (_) => FakeHttpAdapter.json(400, <String, Object?>{
          'statusCode': 400,
          'message': <String>['email must be an email'],
          'error': 'Bad Request',
        }),
      );

      await expectLater(
        sut.repository.register(email: 'nope', password: 'x', name: 'Ada'),
        throwsA(
          isA<ApiStatusException>().having(
            (ApiStatusException e) => e.message,
            'message',
            'email must be an email',
          ),
        ),
      );
    });

    test('surfaces a duplicate email as a 409 conflict', () async {
      final ({AuthRepository repository, FakeHttpAdapter adapter}) sut = _build(
        (_) => FakeHttpAdapter.json(409, <String, Object?>{
          'statusCode': 409,
          'message': 'Email is already registered',
        }),
      );

      await expectLater(
        sut.repository.register(
          email: 'taken@example.com',
          password: 'hunter2!!',
          name: 'Ada',
        ),
        throwsA(
          isA<ApiStatusException>().having(
            (ApiStatusException e) => e.isConflict,
            'isConflict',
            isTrue,
          ),
        ),
      );
    });
  });

  group('AuthRepository.me', () {
    test('parses the profile, mapping the role enum', () async {
      final ({AuthRepository repository, FakeHttpAdapter adapter}) sut = _build(
        (_) => FakeHttpAdapter.json(200, <String, Object?>{
          ..._user,
          'role': 'ADMIN',
        }),
      );

      final AuthUser user = await sut.repository.me();

      expect(sut.adapter.requests.single.path, '/auth/me');
      expect(sut.adapter.requests.single.method, 'GET');
      expect(user.role, UserRole.admin);
      expect(user.email, 'customer@example.com');
    });

    test('does not opt out of the refresh flow', () async {
      // The opposite of `login`: an expired access token here *should* be
      // refreshed transparently.
      final ({AuthRepository repository, FakeHttpAdapter adapter}) sut = _build(
        (_) => FakeHttpAdapter.json(200, _user),
      );

      await sut.repository.me();

      expect(
        sut.adapter.requests.single.extra[AuthInterceptor.skipAuthFlag],
        isNot(isTrue),
      );
    });
  });

  group('AuthRepository.logout', () {
    test('revokes the refresh token server-side', () async {
      final ({AuthRepository repository, FakeHttpAdapter adapter}) sut = _build(
        (_) => FakeHttpAdapter.noContent(),
      );

      await sut.repository.logout('refresh-1');

      final RequestOptions request = sut.adapter.requests.single;
      expect(request.path, '/auth/logout');
      expect(request.data, <String, String>{'refreshToken': 'refresh-1'});
    });

    test('reports a failed revocation as an ApiException', () async {
      final ({AuthRepository repository, FakeHttpAdapter adapter}) sut = _build(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );

      await expectLater(
        sut.repository.logout('refresh-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('AuthUser', () {
    test('treats any non-ADMIN role as a customer', () {
      expect(
        AuthUser.fromJson(<String, Object?>{..._user, 'role': 'admin'}).role,
        UserRole.admin,
      );
      expect(
        AuthUser.fromJson(<String, Object?>{
          ..._user,
          'role': 'SOMETHING',
        }).role,
        UserRole.customer,
      );
    });

    test('compares by value', () {
      expect(AuthUser.fromJson(_user), AuthUser.fromJson(_user));
      expect(
        AuthUser.fromJson(_user).hashCode,
        AuthUser.fromJson(_user).hashCode,
      );
    });
  });
}

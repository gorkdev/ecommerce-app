import 'package:dio/dio.dart';
import 'package:ecommerce_app/core/network/auth_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/in_memory_token_storage.dart';

const String _baseUrl = 'https://api.test';

/// Wires a main client (interceptor attached) and the bare client the
/// interceptor uses for refreshing and replaying, both onto one fake transport
/// so a test can see every request in order.
final class _Harness {
  _Harness(FakeResponder responder, {String? accessToken, String? refreshToken})
    : adapter = FakeHttpAdapter(responder),
      storage = InMemoryTokenStorage(
        accessToken: accessToken,
        refreshToken: refreshToken,
      ) {
    final Dio bareClient = Dio(_options())..httpClientAdapter = adapter;
    dio = Dio(_options())..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        client: bareClient,
        onSessionExpired: () async => sessionExpiredCount++,
      ),
    );
  }

  static BaseOptions _options() =>
      BaseOptions(baseUrl: _baseUrl, contentType: Headers.jsonContentType);

  final FakeHttpAdapter adapter;
  final InMemoryTokenStorage storage;
  late final Dio dio;
  int sessionExpiredCount = 0;

  int get refreshCallCount => adapter.requestsTo('/auth/refresh').length;
}

ResponseBody _unauthorized() => FakeHttpAdapter.json(401, <String, Object?>{
  'statusCode': 401,
  'message': 'Unauthorized',
});

ResponseBody _rotatedTokens() => FakeHttpAdapter.json(200, <String, String>{
  'accessToken': 'access-2',
  'refreshToken': 'refresh-2',
});

void main() {
  group('AuthInterceptor', () {
    test('attaches the stored access token', () async {
      final _Harness harness = _Harness(
        (_) => FakeHttpAdapter.json(200, <String, bool>{'ok': true}),
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );

      await harness.dio.get<dynamic>('/me');

      expect(
        harness.adapter.requests.single.headers['Authorization'],
        'Bearer access-1',
      );
    });

    test('sends no Authorization header when signed out', () async {
      final _Harness harness = _Harness(
        (_) => FakeHttpAdapter.json(200, <String, bool>{'ok': true}),
      );

      await harness.dio.get<dynamic>('/products');

      expect(
        harness.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('skips the header for requests flagged as unauthenticated', () async {
      final _Harness harness = _Harness(
        (_) => FakeHttpAdapter.json(200, <String, bool>{'ok': true}),
        accessToken: 'access-1',
      );

      await harness.dio.post<dynamic>(
        '/auth/login',
        options: Options(
          extra: <String, Object?>{AuthInterceptor.skipAuthFlag: true},
        ),
      );

      expect(
        harness.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test(
      'refreshes on 401, stores the rotated pair, replays the call',
      () async {
        final _Harness harness = _Harness(
          (RequestOptions options) {
            if (options.path == '/auth/refresh') return _rotatedTokens();
            if (options.headers['Authorization'] == 'Bearer access-2') {
              return FakeHttpAdapter.json(200, <String, bool>{'ok': true});
            }
            return _unauthorized();
          },
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
        );

        final Response<dynamic> response = await harness.dio.get<dynamic>(
          '/me',
        );

        expect(response.statusCode, 200);
        expect(harness.refreshCallCount, 1);
        expect(harness.storage.accessToken, 'access-2');
        expect(harness.storage.refreshToken, 'refresh-2');
        expect(harness.sessionExpiredCount, 0);
        // Original 401, refresh, replay.
        expect(harness.adapter.requests, hasLength(3));
        expect(harness.adapter.requests.last.path, '/me');
      },
    );

    test('sends the stored refresh token to /auth/refresh', () async {
      final _Harness harness = _Harness(
        (RequestOptions options) {
          if (options.path == '/auth/refresh') return _rotatedTokens();
          if (options.headers['Authorization'] == 'Bearer access-2') {
            return FakeHttpAdapter.json(200, <String, bool>{'ok': true});
          }
          return _unauthorized();
        },
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );

      await harness.dio.get<dynamic>('/me');

      final RequestOptions refresh = harness.adapter
          .requestsTo('/auth/refresh')
          .single;
      expect(refresh.data, <String, String>{'refreshToken': 'refresh-1'});
      // The refresh call must never be intercepted by itself.
      expect(refresh.extra[AuthInterceptor.skipAuthFlag], isTrue);
    });

    test('collapses concurrent 401s into a single refresh', () async {
      // The API rotates refresh tokens, so a second concurrent refresh would
      // present an already-consumed token and kill the session.
      final _Harness harness = _Harness(
        (RequestOptions options) async {
          if (options.path == '/auth/refresh') {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return _rotatedTokens();
          }
          if (options.headers['Authorization'] == 'Bearer access-2') {
            return FakeHttpAdapter.json(200, <String, String>{
              'path': options.path,
            });
          }
          return _unauthorized();
        },
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );

      final List<Response<dynamic>> responses =
          await Future.wait(<Future<Response<dynamic>>>[
            harness.dio.get<dynamic>('/cart'),
            harness.dio.get<dynamic>('/orders'),
            harness.dio.get<dynamic>('/favorites'),
          ]);

      expect(
        responses.map((Response<dynamic> r) => r.statusCode),
        everyElement(200),
      );
      expect(harness.refreshCallCount, 1);
      expect(harness.storage.saveCount, 1);
      expect(harness.sessionExpiredCount, 0);
    });

    test('refreshes again after an earlier refresh has settled', () async {
      // The in-flight future must be released once it completes, otherwise the
      // session could only ever be refreshed a single time per app launch.
      int refreshes = 0;
      final _Harness harness = _Harness(
        (RequestOptions options) {
          if (options.path == '/auth/refresh') {
            refreshes++;
            return FakeHttpAdapter.json(200, <String, String>{
              'accessToken': 'access-$refreshes',
              'refreshToken': 'refresh-$refreshes',
            });
          }
          return options.headers['Authorization'] == 'Bearer stale'
              ? _unauthorized()
              : FakeHttpAdapter.json(200, <String, bool>{'ok': true});
        },
        accessToken: 'stale',
        refreshToken: 'refresh-0',
      );

      await harness.dio.get<dynamic>('/me');
      expect(harness.refreshCallCount, 1);
      expect(harness.storage.accessToken, 'access-1');

      // The freshly issued token expires later in the session.
      harness.storage.accessToken = 'stale';
      await harness.dio.get<dynamic>('/me');

      expect(harness.refreshCallCount, 2);
      expect(harness.storage.accessToken, 'access-2');
      expect(
        harness.adapter.requestsTo('/auth/refresh').last.data,
        <String, String>{'refreshToken': 'refresh-1'},
      );
    });

    test('does not refresh when the 401 came from an auth endpoint', () async {
      // A wrong password is a 401 too — refreshing (and signing the user out)
      // would be exactly the wrong response.
      final _Harness harness = _Harness(
        (_) => _unauthorized(),
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );

      await expectLater(
        harness.dio.post<dynamic>(
          '/auth/login',
          options: Options(
            extra: <String, Object?>{AuthInterceptor.skipAuthFlag: true},
          ),
        ),
        throwsA(isA<DioException>()),
      );

      expect(harness.refreshCallCount, 0);
      expect(harness.sessionExpiredCount, 0);
      expect(harness.storage.clearCount, 0);
      expect(harness.storage.accessToken, 'access-1');
    });

    test(
      'wipes the tokens and signals expiry when the refresh is rejected',
      () async {
        final _Harness harness = _Harness(
          (_) => _unauthorized(),
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
        );

        await expectLater(
          harness.dio.get<dynamic>('/me'),
          throwsA(
            isA<DioException>().having(
              (DioException e) => e.response?.statusCode,
              'status of the original request',
              401,
            ),
          ),
        );

        expect(harness.refreshCallCount, 1);
        expect(harness.storage.clearCount, 1);
        expect(harness.storage.accessToken, isNull);
        expect(harness.sessionExpiredCount, 1);
      },
    );

    test(
      'does not call /auth/refresh when no refresh token is stored',
      () async {
        final _Harness harness = _Harness(
          (_) => _unauthorized(),
          accessToken: 'access-1',
        );

        await expectLater(
          harness.dio.get<dynamic>('/me'),
          throwsA(isA<DioException>()),
        );

        expect(harness.refreshCallCount, 0);
        expect(harness.sessionExpiredCount, 1);
        expect(harness.storage.clearCount, 1);
      },
    );

    test('never replays more than once', () async {
      // The replayed request 401s as well: the interceptor must surface it, not
      // spin.
      final _Harness harness = _Harness(
        (RequestOptions options) {
          if (options.path == '/auth/refresh') return _rotatedTokens();
          return _unauthorized();
        },
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );

      await expectLater(
        harness.dio.get<dynamic>('/me'),
        throwsA(isA<DioException>()),
      );

      // Original, refresh, single replay — and nothing more.
      expect(harness.adapter.requests, hasLength(3));
      expect(harness.refreshCallCount, 1);
    });

    test('surfaces non-401 failures untouched', () async {
      final _Harness harness = _Harness(
        (_) => FakeHttpAdapter.json(500, <String, String>{'message': 'boom'}),
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );

      await expectLater(
        harness.dio.get<dynamic>('/me'),
        throwsA(isA<DioException>()),
      );

      expect(harness.refreshCallCount, 0);
      expect(harness.storage.clearCount, 0);
    });
  });
}

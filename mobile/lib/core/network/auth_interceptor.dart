import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the access token to every call and, on a 401, refreshes it once and
/// replays the original request.
///
/// The API **rotates** refresh tokens: `POST /auth/refresh` deletes the token it
/// was given and issues a new pair. So two requests that expire at the same
/// moment must not each start their own refresh — the second would present a
/// token the server has already consumed and the user would be signed out for
/// no reason. Every 401 therefore awaits the *same* in-flight refresh future.
///
/// Replaying the request only works for buffered bodies (JSON, form data). A
/// streamed upload cannot be re-sent; those calls should be issued with
/// [skipAuthFlag] unset but a pre-warmed token instead.
final class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage storage,
    required Dio client,
    required Future<void> Function() onSessionExpired,
  }) : _storage = storage,
       _client = client,
       _onSessionExpired = onSessionExpired;

  /// Set on `RequestOptions.extra` to opt a call out of the whole dance.
  /// The `/auth/*` endpoints use it: a 401 from `POST /auth/login` means "wrong
  /// password", not "expired session", and must never trigger a refresh.
  static const String skipAuthFlag = 'auth.skip';

  /// Set on the replayed request so a second 401 cannot loop forever.
  static const String _retriedFlag = 'auth.retried';

  final TokenStorage _storage;

  /// A bare Dio — no interceptors — used for the refresh call and the replay.
  /// Sharing the main client here would recurse back into this interceptor.
  final Dio _client;

  final Future<void> Function() _onSessionExpired;

  Future<bool>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthFlag] != true) {
      final accessToken = await _storage.readAccessToken();
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final shouldRefresh =
        err.response?.statusCode == 401 &&
        options.extra[skipAuthFlag] != true &&
        options.extra[_retriedFlag] != true;

    if (!shouldRefresh) {
      handler.next(err);
      return;
    }

    if (!await _refreshOnce()) {
      await _storage.clear();
      await _onSessionExpired();
      handler.next(err);
      return;
    }

    try {
      handler.resolve(await _replay(options));
    } on DioException catch (error) {
      handler.next(error);
    }
  }

  /// Collapses concurrent refreshes into a single request. The future is
  /// cleared once it settles so a later 401 can refresh again.
  Future<bool> _refreshOnce() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, String>{'refreshToken': refreshToken},
        options: Options(extra: <String, Object?>{skipAuthFlag: true}),
      );
      final body = response.data;
      final accessToken = body?['accessToken'];
      final rotatedRefreshToken = body?['refreshToken'];
      if (accessToken is! String || rotatedRefreshToken is! String) {
        return false;
      }
      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: rotatedRefreshToken,
      );
      return true;
    } on DioException {
      return false;
    }
  }

  Future<Response<dynamic>> _replay(RequestOptions options) async {
    final accessToken = await _storage.readAccessToken();
    return _client.fetch<dynamic>(
      options.copyWith(
        headers: <String, dynamic>{
          ...options.headers,
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
        extra: <String, dynamic>{...options.extra, _retriedFlag: true},
      ),
    );
  }
}

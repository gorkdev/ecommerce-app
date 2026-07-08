import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';

/// Typed client for `/auth/*`.
///
/// Everything above this layer sees [AuthSession]/[AuthUser] and [ApiException];
/// Dio stops here.
///
/// Left open (not `final`) so tests can stand in a mock for it.
class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  /// The credential endpoints are deliberately excluded from the refresh flow:
  /// a 401 from `login` means the password is wrong, not that a token expired.
  Options get _unauthenticated =>
      Options(extra: <String, Object?>{AuthInterceptor.skipAuthFlag: true});

  Future<AuthSession> register({
    required String email,
    required String password,
    required String name,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: <String, String>{
          'email': email,
          'password': password,
          'name': name,
        },
        options: _unauthenticated,
      );
      return AuthSession.fromJson(_requireBody(response));
    });
  }

  Future<AuthSession> login({required String email, required String password}) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: <String, String>{'email': email, 'password': password},
        options: _unauthenticated,
      );
      return AuthSession.fromJson(_requireBody(response));
    });
  }

  Future<AuthUser> me() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      return AuthUser.fromJson(_requireBody(response));
    });
  }

  /// Revokes the refresh token server-side. The access token stays valid until
  /// it expires — that is inherent to stateless JWTs, which is why the TTL is
  /// short.
  Future<void> logout(String refreshToken) {
    return _guard(() async {
      await _dio.post<void>(
        '/auth/logout',
        data: <String, String>{'refreshToken': refreshToken},
        options: _unauthenticated,
      );
    });
  }

  /// A 2xx with no JSON body would otherwise blow up somewhere far from here.
  Map<String, dynamic> _requireBody(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data == null) {
      throw const UnexpectedApiException('The server returned an empty body.');
    }
    return data;
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));

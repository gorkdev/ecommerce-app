import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// Typed client for `/notifications/tokens`.
///
/// Left open (not `final`) so tests can stand in a mock for it.
class NotificationsRepository {
  const NotificationsRepository(this._dio);

  final Dio _dio;

  /// Registration is an upsert server-side: re-sending the same token is how
  /// its account, platform, and notification language stay current.
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    required String locale,
  }) {
    return _guard(() async {
      await _dio.post<Map<String, dynamic>>(
        '/notifications/tokens',
        data: <String, String>{
          'token': token,
          'platform': platform,
          'locale': locale,
        },
      );
    });
  }

  /// Sign-out cleanup; the server answers 204 whether or not the token was
  /// still there.
  Future<void> removeDeviceToken(String token) {
    return _guard(() async {
      await _dio.delete<void>(
        '/notifications/tokens/${Uri.encodeComponent(token)}',
      );
    });
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}

final Provider<NotificationsRepository> notificationsRepositoryProvider =
    Provider<NotificationsRepository>(
      (ref) => NotificationsRepository(ref.watch(dioProvider)),
    );

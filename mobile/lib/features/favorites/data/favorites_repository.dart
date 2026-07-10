import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/favorite.dart';

/// Typed client for `/favorites`.
///
/// Left open (not `final`) so tests can stand in a mock for it.
class FavoritesRepository {
  const FavoritesRepository(this._dio);

  final Dio _dio;

  Future<List<Favorite>> list() {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>('/favorites');
      return _parseList(response.data);
    });
  }

  /// Idempotent server-side: re-favouriting is a no-op, not an error.
  /// Returns the fresh, full list.
  Future<List<Favorite>> add(String productId) {
    return _guard(() async {
      final response = await _dio.post<List<dynamic>>('/favorites/$productId');
      return _parseList(response.data);
    });
  }

  /// 204 on success; a 404 means it was already gone.
  Future<void> remove(String productId) {
    return _guard(() async {
      await _dio.delete<void>('/favorites/$productId');
    });
  }

  List<Favorite> _parseList(List<dynamic>? data) {
    if (data == null) {
      throw const UnexpectedApiException('The server returned an empty body.');
    }
    return data
        .map((item) => Favorite.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}

final Provider<FavoritesRepository> favoritesRepositoryProvider =
    Provider<FavoritesRepository>(
      (ref) => FavoritesRepository(ref.watch(dioProvider)),
    );

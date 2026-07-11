import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/review.dart';

/// Typed client for `/products/:id/reviews`.
///
/// Left open (not `final`) so tests can stand in a mock for it.
class ReviewsRepository {
  const ReviewsRepository(this._dio);

  final Dio _dio;

  /// Public: every review plus the rating summary.
  Future<ProductReviews> fetchForProduct(String productId) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/products/$productId/reviews',
      );
      final Map<String, dynamic>? body = response.data;
      if (body == null) {
        throw const UnexpectedApiException(
          'The server returned an empty body.',
        );
      }
      return ProductReviews.fromJson(body);
    });
  }

  /// The caller's own review — null when they have not written one (the
  /// server answers 200 with an empty body).
  Future<Review?> fetchOwn(String productId) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/products/$productId/reviews/me',
      );
      final Map<String, dynamic>? body = response.data;
      return body == null ? null : Review.fromJson(body);
    });
  }

  /// Creates or overwrites the caller's single review (server-side upsert).
  /// Rejected with a 403 unless the caller actually purchased the product.
  Future<Review> submit(
    String productId, {
    required int rating,
    String? comment,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/products/$productId/reviews',
        data: <String, Object>{'rating': rating, 'comment': ?comment},
      );
      final Map<String, dynamic>? body = response.data;
      if (body == null) {
        throw const UnexpectedApiException(
          'The server returned an empty body.',
        );
      }
      return Review.fromJson(body);
    });
  }

  Future<void> removeOwn(String productId) {
    return _guard(() => _dio.delete<void>('/products/$productId/reviews/me'));
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}

final Provider<ReviewsRepository> reviewsRepositoryProvider =
    Provider<ReviewsRepository>(
      (ref) => ReviewsRepository(ref.watch(dioProvider)),
    );

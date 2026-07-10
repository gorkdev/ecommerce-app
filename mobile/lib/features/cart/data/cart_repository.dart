import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/cart.dart';

/// Typed client for `/cart`. Every mutation returns the full, fresh cart, so
/// callers replace their state wholesale instead of patching it locally.
///
/// Left open (not `final`) so tests can stand in a mock for it.
class CartRepository {
  const CartRepository(this._dio);

  final Dio _dio;

  Future<Cart> fetchCart() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/cart');
      return Cart.fromJson(_requireBody(response));
    });
  }

  /// Adding a product already in the cart accumulates its quantity server-side.
  Future<Cart> addItem({required String productId, required int quantity}) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/cart/items',
        data: <String, Object>{'productId': productId, 'quantity': quantity},
      );
      return Cart.fromJson(_requireBody(response));
    });
  }

  /// Sets the line to an absolute quantity (1..99).
  Future<Cart> updateItem({required String productId, required int quantity}) {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/cart/items/$productId',
        data: <String, Object>{'quantity': quantity},
      );
      return Cart.fromJson(_requireBody(response));
    });
  }

  Future<Cart> removeItem(String productId) {
    return _guard(() async {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/cart/items/$productId',
      );
      return Cart.fromJson(_requireBody(response));
    });
  }

  Future<Cart> clear() {
    return _guard(() async {
      final response = await _dio.delete<Map<String, dynamic>>('/cart');
      return Cart.fromJson(_requireBody(response));
    });
  }

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

final Provider<CartRepository> cartRepositoryProvider =
    Provider<CartRepository>((ref) => CartRepository(ref.watch(dioProvider)));

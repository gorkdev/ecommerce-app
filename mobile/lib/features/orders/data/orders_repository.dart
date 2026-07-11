import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/order.dart';

/// Typed client for `/orders`: the caller's own order history.
///
/// Left open (not `final`) so tests can stand in a mock for it.
class OrdersRepository {
  const OrdersRepository(this._dio);

  final Dio _dio;

  /// Every order the user has placed, newest first (server-sorted).
  Future<List<Order>> fetchOrders() {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>('/orders');
      final List<dynamic> body = response.data ?? const <dynamic>[];
      return body
          .map((order) => Order.fromJson(order as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Order> fetchOrder(String id) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/orders/$id');
      final Map<String, dynamic>? body = response.data;
      if (body == null) {
        throw const UnexpectedApiException(
          'The server returned an empty body.',
        );
      }
      return Order.fromJson(body);
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

final Provider<OrdersRepository> ordersRepositoryProvider =
    Provider<OrdersRepository>(
      (ref) => OrdersRepository(ref.watch(dioProvider)),
    );

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/checkout_session.dart';
import '../domain/coupon_quote.dart';

/// Typed client for checkout: placing the order and quoting coupon codes.
///
/// Left open (not `final`) so tests can stand in a mock for it.
class CheckoutRepository {
  const CheckoutRepository(this._dio);

  final Dio _dio;

  /// Turns the server-side cart into a PENDING order (reserving stock and
  /// emptying the cart) and returns the PaymentIntent client secret.
  Future<CheckoutSession> placeOrder({String? couponCode}) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/orders/checkout',
        data: <String, Object>{'couponCode': ?couponCode},
      );
      return CheckoutSession.fromJson(_requireBody(response));
    });
  }

  /// Quotes what [code] would discount against the current cart. Validation
  /// errors (expired, below minimum, unknown code) arrive as [ApiException]s
  /// carrying the server's message.
  Future<CouponQuote> previewCoupon(String code) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/coupons/apply',
        data: <String, Object>{'code': code},
      );
      return CouponQuote.fromJson(_requireBody(response));
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

final Provider<CheckoutRepository> checkoutRepositoryProvider =
    Provider<CheckoutRepository>(
      (ref) => CheckoutRepository(ref.watch(dioProvider)),
    );

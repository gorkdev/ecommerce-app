import 'package:dio/dio.dart';
import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/checkout/data/checkout_repository.dart';
import 'package:ecommerce_app/features/checkout/domain/checkout_session.dart';
import 'package:ecommerce_app/features/checkout/domain/coupon_quote.dart';
import 'package:ecommerce_app/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_adapter.dart';

const Map<String, Object?> _sessionJson = <String, Object?>{
  'order': <String, Object?>{
    'id': 'ord_1',
    'userId': 'usr_1',
    'status': 'PENDING',
    'subtotal': '114.80',
    'discountTotal': '0',
    'total': '114.80',
    'currency': 'TRY',
    'addressId': null,
    'couponId': null,
    'stripePaymentIntentId': 'pi_123',
    'createdAt': '2026-07-11T09:30:00.000Z',
    'updatedAt': '2026-07-11T09:30:00.000Z',
    'items': <Object?>[
      <String, Object?>{
        'id': 'oi_1',
        'orderId': 'ord_1',
        'productId': 'prd_1',
        'nameSnapshot': 'Ceramic Mug',
        'priceSnapshot': '49.90',
        'quantity': 2,
        'product': <String, Object?>{
          'id': 'prd_1',
          'slug': 'ceramic-mug',
          'images': <Object?>[],
        },
      },
    ],
    'address': null,
    'coupon': null,
  },
  'clientSecret': 'pi_123_secret_456',
};

const Map<String, Object?> _quoteJson = <String, Object?>{
  'code': 'SAVE10',
  'type': 'FIXED',
  'currency': 'TRY',
  'subtotal': '114.80',
  'discount': '10.00',
  'total': '104.80',
};

({CheckoutRepository repository, FakeHttpAdapter adapter}) _build(
  FakeResponder responder,
) {
  final FakeHttpAdapter adapter = FakeHttpAdapter(responder);
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test',
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = adapter;
  return (repository: CheckoutRepository(dio), adapter: adapter);
}

void main() {
  test('placeOrder POSTs /orders/checkout and parses the session', () async {
    final sut = _build((_) => FakeHttpAdapter.json(201, _sessionJson));

    final CheckoutSession session = await sut.repository.placeOrder();

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/orders/checkout');
    expect(request.method, 'POST');
    // No coupon: the body must not carry the key at all.
    expect(request.data, <String, Object>{});
    expect(session.clientSecret, 'pi_123_secret_456');
    expect(session.order.id, 'ord_1');
    expect(session.order.status, OrderStatus.pending);
  });

  test('placeOrder forwards the coupon code when one is applied', () async {
    final sut = _build((_) => FakeHttpAdapter.json(201, _sessionJson));

    await sut.repository.placeOrder(couponCode: 'SAVE10');

    expect(sut.adapter.requests.single.data, <String, Object>{
      'couponCode': 'SAVE10',
    });
  });

  test('placeOrder surfaces checkout validation errors verbatim', () async {
    final sut = _build(
      (_) => FakeHttpAdapter.json(400, <String, Object?>{
        'statusCode': 400,
        'message': 'Not enough stock for "Ceramic Mug"',
        'error': 'Bad Request',
      }),
    );

    await expectLater(
      sut.repository.placeOrder(),
      throwsA(
        isA<ApiStatusException>().having(
          (ApiStatusException e) => e.message,
          'message',
          'Not enough stock for "Ceramic Mug"',
        ),
      ),
    );
  });

  test('previewCoupon POSTs /coupons/apply and parses the quote', () async {
    final sut = _build((_) => FakeHttpAdapter.json(201, _quoteJson));

    final CouponQuote quote = await sut.repository.previewCoupon('save10');

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/coupons/apply');
    expect(request.method, 'POST');
    expect(request.data, <String, Object>{'code': 'save10'});
    expect(quote.code, 'SAVE10');
    expect(quote.discount, '10.00');
    expect(quote.total, '104.80');
  });

  test('previewCoupon surfaces the server rejection message', () async {
    final sut = _build(
      (_) => FakeHttpAdapter.json(404, <String, Object?>{
        'statusCode': 404,
        'message': 'Coupon not found',
        'error': 'Not Found',
      }),
    );

    await expectLater(
      sut.repository.previewCoupon('NOPE'),
      throwsA(
        isA<ApiStatusException>().having(
          (ApiStatusException e) => e.message,
          'message',
          'Coupon not found',
        ),
      ),
    );
  });
}

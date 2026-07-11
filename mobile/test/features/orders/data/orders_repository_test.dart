import 'package:dio/dio.dart';
import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/orders/data/orders_repository.dart';
import 'package:ecommerce_app/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_adapter.dart';

const Map<String, Object?> _orderJson = <String, Object?>{
  'id': 'ord_1',
  'userId': 'usr_1',
  'status': 'PAID',
  'subtotal': '114.80',
  'discountTotal': '0',
  'total': '114.80',
  'currency': 'TRY',
  'addressId': null,
  'couponId': null,
  'stripePaymentIntentId': 'pi_123',
  'createdAt': '2026-07-11T09:30:00.000Z',
  'updatedAt': '2026-07-11T09:35:00.000Z',
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
};

({OrdersRepository repository, FakeHttpAdapter adapter}) _build(
  FakeResponder responder,
) {
  final FakeHttpAdapter adapter = FakeHttpAdapter(responder);
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test',
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = adapter;
  return (repository: OrdersRepository(dio), adapter: adapter);
}

void main() {
  test('fetchOrders GETs /orders and parses the list', () async {
    final sut = _build(
      (_) => FakeHttpAdapter.json(200, <Object?>[_orderJson]),
    );

    final List<Order> orders = await sut.repository.fetchOrders();

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/orders');
    expect(request.method, 'GET');
    expect(orders, hasLength(1));
    expect(orders.single.status, OrderStatus.paid);
    expect(orders.single.itemCount, 2);
  });

  test('fetchOrders tolerates an empty history', () async {
    final sut = _build((_) => FakeHttpAdapter.json(200, <Object?>[]));

    expect(await sut.repository.fetchOrders(), isEmpty);
  });

  test('fetchOrder GETs the order by id', () async {
    final sut = _build((_) => FakeHttpAdapter.json(200, _orderJson));

    final Order order = await sut.repository.fetchOrder('ord_1');

    expect(sut.adapter.requests.single.path, '/orders/ord_1');
    expect(order.id, 'ord_1');
  });

  test('a foreign or missing order surfaces the 404 message', () async {
    final sut = _build(
      (_) => FakeHttpAdapter.json(404, <String, Object?>{
        'statusCode': 404,
        'message': 'Order not found',
        'error': 'Not Found',
      }),
    );

    await expectLater(
      sut.repository.fetchOrder('ord_nope'),
      throwsA(
        isA<ApiStatusException>()
            .having((ApiStatusException e) => e.isNotFound, 'isNotFound', true)
            .having(
              (ApiStatusException e) => e.message,
              'message',
              'Order not found',
            ),
      ),
    );
  });
}

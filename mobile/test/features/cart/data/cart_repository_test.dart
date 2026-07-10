import 'package:dio/dio.dart';
import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/cart/data/cart_repository.dart';
import 'package:ecommerce_app/features/cart/domain/cart.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_adapter.dart';

const Map<String, Object?> _cartJson = <String, Object?>{
  'id': 'cart_1',
  'items': <Object?>[
    <String, Object?>{
      'id': 'ci_1',
      'cartId': 'cart_1',
      'productId': 'prd_1',
      'quantity': 2,
      'product': <String, Object?>{
        'id': 'prd_1',
        'slug': 'ceramic-mug',
        'name': 'Ceramic Mug',
        'price': '49.90',
        'currency': 'TRY',
        'stock': 10,
        'isActive': true,
        'images': <Object?>[],
      },
    },
  ],
  'summary': <String, Object?>{
    'itemCount': 2,
    'subtotal': '99.80',
    'currency': 'TRY',
  },
};

({CartRepository repository, FakeHttpAdapter adapter}) _build(
  FakeResponder responder,
) {
  final FakeHttpAdapter adapter = FakeHttpAdapter(responder);
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test',
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = adapter;
  return (repository: CartRepository(dio), adapter: adapter);
}

void main() {
  test('fetchCart GETs /cart and parses it', () async {
    final sut = _build((_) => FakeHttpAdapter.json(200, _cartJson));

    final Cart cart = await sut.repository.fetchCart();

    expect(cart.summary.itemCount, 2);
    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/cart');
    expect(request.method, 'GET');
  });

  test('addItem POSTs the product and quantity', () async {
    final sut = _build((_) => FakeHttpAdapter.json(200, _cartJson));

    await sut.repository.addItem(productId: 'prd_1', quantity: 2);

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/cart/items');
    expect(request.method, 'POST');
    expect(request.data, <String, Object>{
      'productId': 'prd_1',
      'quantity': 2,
    });
  });

  test('updateItem PATCHes the line by product id', () async {
    final sut = _build((_) => FakeHttpAdapter.json(200, _cartJson));

    await sut.repository.updateItem(productId: 'prd_1', quantity: 5);

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/cart/items/prd_1');
    expect(request.method, 'PATCH');
    expect(request.data, <String, Object>{'quantity': 5});
  });

  test('removeItem DELETEs the line and clear DELETEs the cart', () async {
    final sut = _build((_) => FakeHttpAdapter.json(200, _cartJson));

    await sut.repository.removeItem('prd_1');
    await sut.repository.clear();

    expect(sut.adapter.requests[0].path, '/cart/items/prd_1');
    expect(sut.adapter.requests[0].method, 'DELETE');
    expect(sut.adapter.requests[1].path, '/cart');
    expect(sut.adapter.requests[1].method, 'DELETE');
  });

  test('surfaces the stock-limit 400 with the server message', () async {
    final sut = _build(
      (_) => FakeHttpAdapter.json(400, <String, Object?>{
        'statusCode': 400,
        'message': 'Only 3 unit(s) of this product are in stock',
        'error': 'Bad Request',
      }),
    );

    await expectLater(
      sut.repository.addItem(productId: 'prd_1', quantity: 4),
      throwsA(
        isA<ApiStatusException>().having(
          (ApiStatusException e) => e.message,
          'message',
          'Only 3 unit(s) of this product are in stock',
        ),
      ),
    );
  });
}

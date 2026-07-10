import 'package:dio/dio.dart';
import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/favorites/data/favorites_repository.dart';
import 'package:ecommerce_app/features/favorites/domain/favorite.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_adapter.dart';

const List<Object?> _favoritesJson = <Object?>[
  <String, Object?>{
    'id': 'fav_1',
    'userId': 'usr_1',
    'productId': 'prd_1',
    'createdAt': '2026-07-01T00:00:00.000Z',
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
];

({FavoritesRepository repository, FakeHttpAdapter adapter}) _build(
  FakeResponder responder,
) {
  final FakeHttpAdapter adapter = FakeHttpAdapter(responder);
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test',
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = adapter;
  return (repository: FavoritesRepository(dio), adapter: adapter);
}

void main() {
  test('list GETs /favorites and parses the entries', () async {
    final sut = _build((_) => FakeHttpAdapter.json(200, _favoritesJson));

    final List<Favorite> favorites = await sut.repository.list();

    expect(favorites.single.productId, 'prd_1');
    expect(favorites.single.product.name, 'Ceramic Mug');
    expect(sut.adapter.requests.single.path, '/favorites');
  });

  test('add POSTs to /favorites/:productId and parses the fresh list', () async {
    final sut = _build((_) => FakeHttpAdapter.json(201, _favoritesJson));

    final List<Favorite> favorites = await sut.repository.add('prd_1');

    expect(favorites, hasLength(1));
    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/favorites/prd_1');
    expect(request.method, 'POST');
  });

  test('remove DELETEs and accepts the empty 204', () async {
    final sut = _build((_) => FakeHttpAdapter.noContent());

    await sut.repository.remove('prd_1');

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/favorites/prd_1');
    expect(request.method, 'DELETE');
  });

  test('surfaces a 404 removal as an ApiStatusException', () async {
    final sut = _build(
      (_) => FakeHttpAdapter.json(404, <String, Object?>{
        'statusCode': 404,
        'message': 'Favorite not found',
        'error': 'Not Found',
      }),
    );

    await expectLater(
      sut.repository.remove('prd_1'),
      throwsA(
        isA<ApiStatusException>().having(
          (ApiStatusException e) => e.isNotFound,
          'isNotFound',
          true,
        ),
      ),
    );
  });
}

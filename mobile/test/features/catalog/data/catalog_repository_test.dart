import 'package:dio/dio.dart';
import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/catalog/data/catalog_repository.dart';
import 'package:ecommerce_app/features/catalog/domain/category.dart';
import 'package:ecommerce_app/features/catalog/domain/paginated.dart';
import 'package:ecommerce_app/features/catalog/domain/product.dart';
import 'package:ecommerce_app/features/catalog/domain/product_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_adapter.dart';

const Map<String, Object?> _productJson = <String, Object?>{
  'id': 'prd_1',
  'slug': 'wireless-headphones',
  'name': 'Wireless Headphones',
  'description': 'Crisp sound.',
  'price': '1299.99',
  'compareAtPrice': null,
  'currency': 'TRY',
  'stock': 3,
  'category': <String, Object?>{'id': 'cat_1', 'slug': 'audio', 'name': 'Audio'},
  'images': <Object?>[],
};

Map<String, Object?> _page(List<Object?> data, {int page = 1, int total = 1}) =>
    <String, Object?>{
      'data': data,
      'meta': <String, Object?>{
        'page': page,
        'limit': 20,
        'total': total,
        'totalPages': (total / 20).ceil(),
      },
    };

({CatalogRepository repository, FakeHttpAdapter adapter}) _build(
  FakeResponder responder,
) {
  final FakeHttpAdapter adapter = FakeHttpAdapter(responder);
  final Dio dio = Dio(
    BaseOptions(baseUrl: 'https://api.test', contentType: Headers.jsonContentType),
  )..httpClientAdapter = adapter;
  return (repository: CatalogRepository(dio), adapter: adapter);
}

void main() {
  group('CatalogRepository.fetchProducts', () {
    test('requests /products and parses the page envelope', () async {
      final sut = _build(
        (_) => FakeHttpAdapter.json(200, _page(<Object?>[_productJson])),
      );

      final Paginated<Product> page = await sut.repository.fetchProducts(
        const ProductQuery(),
      );

      expect(page.items.single.name, 'Wireless Headphones');
      expect(page.total, 1);

      final RequestOptions request = sut.adapter.requests.single;
      expect(request.path, '/products');
      expect(request.method, 'GET');
      expect(request.queryParameters, isEmpty);
    });

    test('sends every active filter as a query parameter', () async {
      final sut = _build(
        (_) => FakeHttpAdapter.json(200, _page(<Object?>[])),
      );

      await sut.repository.fetchProducts(
        const ProductQuery()
            .withSearch('head')
            .withCategory('cat_1')
            .withPriceRange(10, 250)
            .withSort(ProductSort.priceAsc)
            .pageAt(2),
      );

      expect(sut.adapter.requests.single.queryParameters, <String, dynamic>{
        'page': 2,
        'search': 'head',
        'categoryId': 'cat_1',
        'minPrice': 10.0,
        'maxPrice': 250.0,
        'sort': 'price_asc',
      });
    });

    test('turns a dead connection into a NetworkException', () async {
      final sut = _build(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'connection refused',
        ),
      );

      await expectLater(
        sut.repository.fetchProducts(const ProductQuery()),
        throwsA(isA<NetworkException>()),
      );
    });

    test('rejects a 2xx with no body instead of crashing later', () async {
      final sut = _build((_) => FakeHttpAdapter.noContent());

      await expectLater(
        sut.repository.fetchProducts(const ProductQuery()),
        throwsA(isA<UnexpectedApiException>()),
      );
    });
  });

  group('CatalogRepository.fetchProduct', () {
    test('addresses the product by slug and parses it', () async {
      final sut = _build((_) => FakeHttpAdapter.json(200, _productJson));

      final Product product = await sut.repository.fetchProduct(
        'wireless-headphones',
      );

      expect(product.id, 'prd_1');
      expect(
        sut.adapter.requests.single.path,
        '/products/wireless-headphones',
      );
    });

    test('surfaces a missing product as a 404 ApiStatusException', () async {
      final sut = _build(
        (_) => FakeHttpAdapter.json(404, <String, Object?>{
          'statusCode': 404,
          'message': 'Product not found',
          'error': 'Not Found',
        }),
      );

      await expectLater(
        sut.repository.fetchProduct('gone'),
        throwsA(
          isA<ApiStatusException>()
              .having((ApiStatusException e) => e.isNotFound, 'isNotFound', true)
              .having(
                (ApiStatusException e) => e.message,
                'message',
                'Product not found',
              ),
        ),
      );
    });
  });

  group('CatalogRepository.fetchCategories', () {
    test('parses the nested category forest', () async {
      final sut = _build(
        (_) => FakeHttpAdapter.json(200, <Object?>[
          <String, Object?>{
            'id': 'cat_1',
            'slug': 'electronics',
            'name': 'Electronics',
            'parentId': null,
            'children': <Object?>[
              <String, Object?>{
                'id': 'cat_2',
                'slug': 'audio',
                'name': 'Audio',
                'parentId': 'cat_1',
                'children': <Object?>[],
              },
            ],
          },
        ]),
      );

      final List<Category> roots = await sut.repository.fetchCategories();

      expect(roots.single.slug, 'electronics');
      expect(roots.single.children.single.slug, 'audio');
      expect(sut.adapter.requests.single.path, '/categories');
    });
  });
}

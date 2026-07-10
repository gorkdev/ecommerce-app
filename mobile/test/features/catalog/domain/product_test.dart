import 'package:ecommerce_app/features/catalog/domain/category.dart';
import 'package:ecommerce_app/features/catalog/domain/paginated.dart';
import 'package:ecommerce_app/features/catalog/domain/product.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _productJson() => <String, Object?>{
  'id': 'prd_1',
  'slug': 'wireless-headphones',
  'name': 'Wireless Headphones',
  'description': 'Crisp sound, all-day battery.',
  'price': '1299.99',
  'compareAtPrice': '1599.99',
  'currency': 'TRY',
  'stock': 12,
  'isActive': true,
  'categoryId': 'cat_1',
  'createdAt': '2026-07-01T00:00:00.000Z',
  'updatedAt': '2026-07-01T00:00:00.000Z',
  'category': <String, Object?>{
    'id': 'cat_1',
    'slug': 'audio',
    'name': 'Audio',
  },
  'images': <Object?>[
    <String, Object?>{
      'id': 'img_1',
      'productId': 'prd_1',
      'url': 'http://localhost:9000/product-images/a.png',
      'sortOrder': 0,
    },
  ],
};

void main() {
  group('Product.fromJson', () {
    test('parses the full catalog payload', () {
      final Product product = Product.fromJson(_productJson());

      expect(product.id, 'prd_1');
      expect(product.slug, 'wireless-headphones');
      expect(product.price, '1299.99');
      expect(product.compareAtPrice, '1599.99');
      expect(product.currency, 'TRY');
      expect(product.stock, 12);
      expect(product.category?.name, 'Audio');
      expect(product.images.single.url, endsWith('/a.png'));
      expect(product.inStock, isTrue);
    });

    test('tolerates the optional fields being absent', () {
      final Map<String, Object?> json = _productJson()
        ..['compareAtPrice'] = null
        ..remove('category')
        ..remove('images');

      final Product product = Product.fromJson(json);

      expect(product.compareAtPrice, isNull);
      expect(product.category, isNull);
      expect(product.images, isEmpty);
      expect(product.discountPercent, isNull);
    });

    test('accepts a bare JSON number for money fields', () {
      // The documented contract is a decimal string, but a serialiser change
      // must not brick the whole catalog.
      final Map<String, Object?> json = _productJson()..['price'] = 1299.99;

      expect(Product.fromJson(json).price, '1299.99');
    });
  });

  group('Product.discountPercent', () {
    Product withPrices(String price, String? compareAt) => Product.fromJson(
      _productJson()
        ..['price'] = price
        ..['compareAtPrice'] = compareAt,
    );

    test('is the rounded percentage off the compare-at price', () {
      expect(withPrices('75.00', '100.00').discountPercent, 25);
    });

    test('hides a compare-at price that is not actually a discount', () {
      expect(withPrices('100.00', '80.00').discountPercent, isNull);
      expect(withPrices('100.00', '100.00').discountPercent, isNull);
    });
  });

  test('a product with zero stock is out of stock', () {
    expect(Product.fromJson(_productJson()..['stock'] = 0).inStock, isFalse);
  });

  group('Category', () {
    test('parses the nested tree recursively', () {
      final Category root = Category.fromJson(<String, Object?>{
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
      });

      expect(root.children.single.name, 'Audio');
      expect(root.children.single.parentId, 'cat_1');
    });

    test('flattens a forest depth-first', () {
      const Category grandchild = Category(
        id: 'c3',
        slug: 'earbuds',
        name: 'Earbuds',
        parentId: 'c2',
        children: <Category>[],
      );
      const Category child = Category(
        id: 'c2',
        slug: 'audio',
        name: 'Audio',
        parentId: 'c1',
        children: <Category>[grandchild],
      );
      const Category rootA = Category(
        id: 'c1',
        slug: 'electronics',
        name: 'Electronics',
        parentId: null,
        children: <Category>[child],
      );
      const Category rootB = Category(
        id: 'c4',
        slug: 'home',
        name: 'Home',
        parentId: null,
        children: <Category>[],
      );

      expect(
        Category.flatten(const <Category>[rootA, rootB])
            .map((Category c) => c.id),
        <String>['c1', 'c2', 'c3', 'c4'],
      );
    });
  });

  group('Paginated', () {
    test('parses the data/meta envelope', () {
      final Paginated<Product> page = Paginated<Product>.fromJson(
        <String, Object?>{
          'data': <Object?>[_productJson()],
          'meta': <String, Object?>{
            'page': 1,
            'limit': 20,
            'total': 45,
            'totalPages': 3,
          },
        },
        Product.fromJson,
      );

      expect(page.items.single.id, 'prd_1');
      expect(page.total, 45);
      expect(page.hasMore, isTrue);
    });

    test('reports no more pages on the last page', () {
      final Paginated<Product> page = Paginated<Product>.fromJson(
        <String, Object?>{
          'data': <Object?>[],
          'meta': <String, Object?>{
            'page': 3,
            'limit': 20,
            'total': 45,
            'totalPages': 3,
          },
        },
        Product.fromJson,
      );

      expect(page.hasMore, isFalse);
    });
  });
}

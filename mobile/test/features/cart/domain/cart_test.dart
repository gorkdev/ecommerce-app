import 'package:ecommerce_app/features/cart/domain/cart.dart';
import 'package:ecommerce_app/features/catalog/domain/product.dart';
import 'package:ecommerce_app/features/catalog/domain/product_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _itemJson({
  String productId = 'prd_1',
  int quantity = 2,
  String price = '49.90',
  List<Object?> images = const <Object?>[
    <String, Object?>{
      'id': 'img_1',
      'productId': 'prd_1',
      'url': 'http://localhost:9000/product-images/a.png',
      'sortOrder': 0,
    },
  ],
}) => <String, Object?>{
  'id': 'ci_1',
  'cartId': 'cart_1',
  'productId': productId,
  'quantity': quantity,
  'product': <String, Object?>{
    'id': productId,
    'slug': 'ceramic-mug',
    'name': 'Ceramic Mug',
    'price': price,
    'currency': 'TRY',
    'stock': 10,
    'isActive': true,
    'images': images,
  },
};

void main() {
  test('Cart.fromJson parses items and the server summary', () {
    final Cart cart = Cart.fromJson(<String, Object?>{
      'id': 'cart_1',
      'items': <Object?>[_itemJson()],
      'summary': <String, Object?>{
        'itemCount': 2,
        'subtotal': '99.80',
        'currency': 'TRY',
      },
    });

    expect(cart.id, 'cart_1');
    expect(cart.isEmpty, isFalse);
    expect(cart.items.single.quantity, 2);
    expect(cart.items.single.product.imageUrl, endsWith('/a.png'));
    expect(cart.summary.itemCount, 2);
    expect(cart.summary.subtotal, '99.80');
  });

  test('an empty cart still carries a summary', () {
    final Cart cart = Cart.fromJson(<String, Object?>{
      'id': 'cart_1',
      'items': <Object?>[],
      'summary': <String, Object?>{
        'itemCount': 0,
        'subtotal': '0.00',
        'currency': 'TRY',
      },
    });

    expect(cart.isEmpty, isTrue);
    expect(cart.summary.subtotal, '0.00');
  });

  test('a product without images has no thumbnail URL', () {
    final Cart cart = Cart.fromJson(<String, Object?>{
      'id': 'cart_1',
      'items': <Object?>[_itemJson(images: const <Object?>[])],
      'summary': <String, Object?>{
        'itemCount': 2,
        'subtotal': '99.80',
        'currency': 'TRY',
      },
    });

    expect(cart.items.single.product.imageUrl, isNull);
  });

  test('lineTotal multiplies for display only', () {
    final CartItem item = CartItem.fromJson(
      _itemJson(quantity: 3, price: '0.10'),
    );

    expect(item.lineTotal, '0.30');
  });

  test('ProductSummary.of converts a full catalog product', () {
    const Product product = Product(
      id: 'prd_1',
      slug: 'ceramic-mug',
      name: 'Ceramic Mug',
      description: '',
      price: '49.90',
      compareAtPrice: null,
      currency: 'TRY',
      stock: 10,
      category: null,
      images: <ProductImage>[
        ProductImage(id: 'img_1', url: 'http://x/a.png', sortOrder: 0),
      ],
    );

    final ProductSummary summary = ProductSummary.of(product);

    expect(summary.id, 'prd_1');
    expect(summary.imageUrl, 'http://x/a.png');
    expect(summary.inStock, isTrue);
  });
}

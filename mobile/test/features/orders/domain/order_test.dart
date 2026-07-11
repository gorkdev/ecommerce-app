import 'package:ecommerce_app/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, Object?> _orderJson = <String, Object?>{
  'id': 'ord_abcdef123456',
  'userId': 'usr_1',
  'status': 'PENDING',
  'subtotal': '129.80',
  'discountTotal': '10.00',
  'total': '119.80',
  'currency': 'TRY',
  'addressId': null,
  'couponId': 'cpn_1',
  'stripePaymentIntentId': 'pi_123',
  'createdAt': '2026-07-11T09:30:00.000Z',
  'updatedAt': '2026-07-11T09:30:00.000Z',
  'items': <Object?>[
    <String, Object?>{
      'id': 'oi_1',
      'orderId': 'ord_abcdef123456',
      'productId': 'prd_1',
      'nameSnapshot': 'Ceramic Mug',
      'priceSnapshot': '49.90',
      'quantity': 2,
      'product': <String, Object?>{
        'id': 'prd_1',
        'slug': 'ceramic-mug',
        'images': <Object?>[
          <String, Object?>{'id': 'img_1', 'url': 'http://localhost:9000/m.jpg'},
        ],
      },
    },
    <String, Object?>{
      'id': 'oi_2',
      'orderId': 'ord_abcdef123456',
      'productId': 'prd_2',
      'nameSnapshot': 'Steel Bottle',
      'priceSnapshot': '30.00',
      'quantity': 1,
      'product': <String, Object?>{
        'id': 'prd_2',
        'slug': 'steel-bottle',
        'images': <Object?>[],
      },
    },
  ],
  'address': null,
  'coupon': <String, Object?>{'id': 'cpn_1', 'code': 'SAVE10', 'type': 'FIXED'},
};

void main() {
  group('Order.fromJson', () {
    test('parses the full checkout response shape', () {
      final Order order = Order.fromJson(
        Map<String, dynamic>.from(_orderJson),
      );

      expect(order.id, 'ord_abcdef123456');
      expect(order.status, OrderStatus.pending);
      expect(order.subtotal, '129.80');
      expect(order.discountTotal, '10.00');
      expect(order.total, '119.80');
      expect(order.currency, 'TRY');
      expect(order.createdAt, DateTime.utc(2026, 7, 11, 9, 30));
      expect(order.coupon?.code, 'SAVE10');
      expect(order.items, hasLength(2));

      final OrderItem mug = order.items.first;
      expect(mug.name, 'Ceramic Mug');
      expect(mug.unitPrice, '49.90');
      expect(mug.quantity, 2);
      expect(mug.productSlug, 'ceramic-mug');
      expect(mug.imageUrl, 'http://localhost:9000/m.jpg');
      expect(order.items[1].imageUrl, isNull);
    });

    test('tolerates a missing coupon and product embed', () {
      final Map<String, dynamic> json = Map<String, dynamic>.from(_orderJson);
      json['coupon'] = null;
      json['items'] = <Object?>[
        <String, Object?>{
          'id': 'oi_1',
          'orderId': 'ord_abcdef123456',
          'productId': 'prd_1',
          'nameSnapshot': 'Ceramic Mug',
          'priceSnapshot': '49.90',
          'quantity': 2,
        },
      ];

      final Order order = Order.fromJson(json);

      expect(order.coupon, isNull);
      expect(order.items.single.productSlug, isNull);
      expect(order.items.single.imageUrl, isNull);
    });

    test('tolerates numeric decimals from JSON', () {
      final Map<String, dynamic> json = Map<String, dynamic>.from(_orderJson);
      json['subtotal'] = 129.8;
      json['discountTotal'] = 0;
      json['total'] = 129.8;

      final Order order = Order.fromJson(json);

      expect(order.subtotal, '129.8');
      expect(order.hasDiscount, isFalse);
    });

    test('rejects an unknown order status', () {
      final Map<String, dynamic> json = Map<String, dynamic>.from(_orderJson);
      json['status'] = 'TELEPORTED';

      expect(() => Order.fromJson(json), throwsFormatException);
    });
  });

  test('hasDiscount reflects the discount total', () {
    final Order order = Order.fromJson(Map<String, dynamic>.from(_orderJson));
    expect(order.hasDiscount, isTrue);
  });

  test('itemCount sums the units across every line', () {
    final Order order = Order.fromJson(Map<String, dynamic>.from(_orderJson));
    expect(order.itemCount, 3); // 2 mugs + 1 bottle
  });

  test('reference is the uppercased tail of the id', () {
    final Order order = Order.fromJson(Map<String, dynamic>.from(_orderJson));
    expect(order.reference, 'EF123456');
  });

  group('OrderItem.lineTotal', () {
    test('multiplies the snapshot price for display', () {
      final Order order = Order.fromJson(Map<String, dynamic>.from(_orderJson));
      expect(order.items.first.lineTotal, '99.80');
    });

    test('falls back to the raw value when unparseable', () {
      const OrderItem item = OrderItem(
        id: 'oi_1',
        productId: 'prd_1',
        name: 'Mug',
        unitPrice: 'not-a-number',
        quantity: 3,
        productSlug: null,
        imageUrl: null,
      );
      expect(item.lineTotal, 'not-a-number');
    });
  });

  group('OrderStatus.parse', () {
    test('maps every wire value the API can send', () {
      expect(OrderStatus.parse('PAID'), OrderStatus.paid);
      expect(OrderStatus.parse('PREPARING'), OrderStatus.preparing);
      expect(OrderStatus.parse('SHIPPED'), OrderStatus.shipped);
      expect(OrderStatus.parse('DELIVERED'), OrderStatus.delivered);
      expect(OrderStatus.parse('CANCELLED'), OrderStatus.cancelled);
      expect(OrderStatus.parse('REFUNDED'), OrderStatus.refunded);
    });
  });
}

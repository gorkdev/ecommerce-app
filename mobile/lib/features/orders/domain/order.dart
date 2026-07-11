/// An order as `/orders` returns it. Lives under `orders/` rather than
/// `checkout/` because the upcoming order-tracking slice reads the same shape.
final class Order {
  const Order({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.discountTotal,
    required this.total,
    required this.currency,
    required this.createdAt,
    required this.items,
    required this.coupon,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    status: OrderStatus.parse(json['status'] as String),
    subtotal: _decimalString(json['subtotal']),
    discountTotal: _decimalString(json['discountTotal']),
    total: _decimalString(json['total']),
    currency: json['currency'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    items: (json['items'] as List<dynamic>)
        .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    coupon: json['coupon'] == null
        ? null
        : OrderCoupon.fromJson(json['coupon'] as Map<String, dynamic>),
  );

  final String id;
  final OrderStatus status;
  final String subtotal;
  final String discountTotal;
  final String total;
  final String currency;
  final DateTime createdAt;
  final List<OrderItem> items;
  final OrderCoupon? coupon;

  bool get hasDiscount => (double.tryParse(discountTotal) ?? 0) > 0;

  /// A human-sized order reference: the tail of the (cuid) id, uppercased.
  String get reference =>
      id.length <= 8 ? id.toUpperCase() : id.substring(id.length - 8).toUpperCase();

  static String _decimalString(Object? value) => switch (value) {
    final String text => text,
    final num number => number.toString(),
    _ => throw FormatException('Not a decimal value: $value'),
  };
}

/// A line frozen at checkout time: the name and unit price are snapshots, so
/// later catalog edits do not rewrite order history.
final class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.productSlug,
    required this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    final List<dynamic> images =
        (product?['images'] as List<dynamic>?) ?? const <dynamic>[];
    return OrderItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      name: json['nameSnapshot'] as String,
      unitPrice: Order._decimalString(json['priceSnapshot']),
      quantity: json['quantity'] as int,
      productSlug: product?['slug'] as String?,
      imageUrl: images.isEmpty
          ? null
          : (images.first as Map<String, dynamic>)['url'] as String?,
    );
  }

  final String id;
  final String productId;
  final String name;
  final String unitPrice;
  final int quantity;

  /// The product may have been deleted since; navigation is best-effort.
  final String? productSlug;
  final String? imageUrl;

  /// Display-only line total; the authoritative totals come with the order.
  String get lineTotal {
    final double? unit = double.tryParse(unitPrice);
    if (unit == null) return unitPrice;
    return (unit * quantity).toStringAsFixed(2);
  }
}

final class OrderCoupon {
  const OrderCoupon({required this.id, required this.code, required this.type});

  factory OrderCoupon.fromJson(Map<String, dynamic> json) => OrderCoupon(
    id: json['id'] as String,
    code: json['code'] as String,
    type: json['type'] as String,
  );

  final String id;
  final String code;
  final String type;
}

/// Order lifecycle exactly as the API's `OrderStatus` enum serializes it.
enum OrderStatus {
  pending('PENDING', 'Pending'),
  paid('PAID', 'Paid'),
  preparing('PREPARING', 'Preparing'),
  shipped('SHIPPED', 'Shipped'),
  delivered('DELIVERED', 'Delivered'),
  cancelled('CANCELLED', 'Cancelled'),
  refunded('REFUNDED', 'Refunded');

  const OrderStatus(this.wire, this.label);

  final String wire;
  final String label;

  static OrderStatus parse(String wire) => values.firstWhere(
    (OrderStatus status) => status.wire == wire,
    orElse: () => throw FormatException('Unknown order status: $wire'),
  );
}

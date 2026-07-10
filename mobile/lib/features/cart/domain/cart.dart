import '../../catalog/domain/product_summary.dart';

/// The server's cart response: lines plus a server-computed summary, so the
/// client never has to trust its own money math for the subtotal.
final class Cart {
  const Cart({required this.id, required this.items, required this.summary});

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
    id: json['id'] as String,
    items: (json['items'] as List<dynamic>)
        .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    summary: CartSummary.fromJson(json['summary'] as Map<String, dynamic>),
  );

  final String id;
  final List<CartItem> items;
  final CartSummary summary;

  bool get isEmpty => items.isEmpty;
}

final class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.product,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id'] as String,
    productId: json['productId'] as String,
    quantity: json['quantity'] as int,
    product: ProductSummary.fromJson(json['product'] as Map<String, dynamic>),
  );

  final String id;
  final String productId;
  final int quantity;
  final ProductSummary product;

  /// Display-only line total. The authoritative money math (the subtotal)
  /// comes from the server; this only multiplies for the row label.
  String get lineTotal {
    final double? unit = double.tryParse(product.price);
    if (unit == null) return product.price;
    return (unit * quantity).toStringAsFixed(2);
  }
}

final class CartSummary {
  const CartSummary({
    required this.itemCount,
    required this.subtotal,
    required this.currency,
  });

  factory CartSummary.fromJson(Map<String, dynamic> json) => CartSummary(
    itemCount: json['itemCount'] as int,
    subtotal: json['subtotal'] as String,
    currency: json['currency'] as String,
  );

  final int itemCount;
  final String subtotal;
  final String currency;
}

import '../../catalog/domain/product_summary.dart';

/// One saved product from `GET /favorites`.
final class Favorite {
  const Favorite({
    required this.id,
    required this.productId,
    required this.product,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
    id: json['id'] as String,
    productId: json['productId'] as String,
    product: ProductSummary.fromJson(json['product'] as Map<String, dynamic>),
  );

  /// A client-side stand-in shown while the optimistic "add" round-trip is in
  /// flight; the server list replaces it the moment the call returns.
  factory Favorite.local(ProductSummary product) => Favorite(
    id: 'local-${product.id}',
    productId: product.id,
    product: product,
  );

  final String id;
  final String productId;
  final ProductSummary product;
}

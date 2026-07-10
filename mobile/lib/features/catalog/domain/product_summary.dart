import 'product.dart';

/// The compact product embed the API nests inside cart items and favorites:
/// just enough to render a row (thumbnail, name, price, stock).
final class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.price,
    required this.currency,
    required this.stock,
    required this.isActive,
    required this.imageUrl,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> json) {
    final List<dynamic> images =
        (json['images'] as List<dynamic>?) ?? const <dynamic>[];
    return ProductSummary(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      price: _decimalString(json['price']),
      currency: json['currency'] as String,
      stock: json['stock'] as int,
      isActive: json['isActive'] as bool,
      imageUrl: images.isEmpty
          ? null
          : (images.first as Map<String, dynamic>)['url'] as String?,
    );
  }

  /// The catalog's full [Product] carries the same core fields — favorites
  /// toggled from a catalog screen convert through here.
  factory ProductSummary.of(Product product) => ProductSummary(
    id: product.id,
    slug: product.slug,
    name: product.name,
    price: product.price,
    currency: product.currency,
    stock: product.stock,
    isActive: true,
    imageUrl: product.images.isEmpty ? null : product.images.first.url,
  );

  final String id;
  final String slug;
  final String name;
  final String price;
  final String currency;
  final int stock;
  final bool isActive;
  final String? imageUrl;

  bool get inStock => stock > 0;

  static String _decimalString(Object? value) => switch (value) {
    final String text => text,
    final num number => number.toString(),
    _ => throw FormatException('Not a decimal value: $value'),
  };
}

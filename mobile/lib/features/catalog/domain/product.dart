/// Catalog product as served by `GET /products` and `GET /products/:slug`.
///
/// Money fields stay [String]s end to end: the API serialises Prisma
/// `Decimal`s as decimal strings and the client only ever formats them.
final class Product {
  const Product({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.price,
    required this.compareAtPrice,
    required this.currency,
    required this.stock,
    required this.category,
    required this.images,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    slug: json['slug'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    price: _decimalString(json['price'])!,
    compareAtPrice: _decimalString(json['compareAtPrice']),
    currency: json['currency'] as String,
    stock: json['stock'] as int,
    category: json['category'] == null
        ? null
        : CategoryRef.fromJson(json['category'] as Map<String, dynamic>),
    images: ((json['images'] as List<dynamic>?) ?? const <dynamic>[])
        .map((image) => ProductImage.fromJson(image as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String slug;
  final String name;
  final String description;
  final String price;
  final String? compareAtPrice;
  final String currency;
  final int stock;
  final CategoryRef? category;
  final List<ProductImage> images;

  bool get inStock => stock > 0;

  /// Rounded percentage off the compare-at price, or `null` when there is no
  /// (sensible) discount to show.
  int? get discountPercent {
    final double? current = double.tryParse(price);
    final double? original = double.tryParse(compareAtPrice ?? '');
    if (current == null || original == null) return null;
    if (original <= current || original <= 0) return null;
    return ((1 - current / original) * 100).round();
  }

  /// Tolerates a plain JSON number in case the serialiser ever changes; the
  /// documented contract is a string.
  static String? _decimalString(Object? value) => switch (value) {
    null => null,
    final String text => text,
    final num number => number.toString(),
    _ => throw FormatException('Not a decimal value: $value'),
  };
}

final class ProductImage {
  const ProductImage({
    required this.id,
    required this.url,
    required this.sortOrder,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
    id: json['id'] as String,
    url: json['url'] as String,
    sortOrder: json['sortOrder'] as int,
  );

  final String id;
  final String url;
  final int sortOrder;
}

/// The embedded `category` summary on a product — not the full tree node.
final class CategoryRef {
  const CategoryRef({required this.id, required this.slug, required this.name});

  factory CategoryRef.fromJson(Map<String, dynamic> json) => CategoryRef(
    id: json['id'] as String,
    slug: json['slug'] as String,
    name: json['name'] as String,
  );

  final String id;
  final String slug;
  final String name;
}

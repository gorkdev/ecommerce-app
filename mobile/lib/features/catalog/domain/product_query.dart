enum ProductSort {
  newest('newest'),
  priceAsc('price_asc'),
  priceDesc('price_desc');

  const ProductSort(this.wire);

  /// The value `GET /products?sort=` expects.
  final String wire;
}

/// Everything the product listing can be narrowed by, mirroring the server's
/// `QueryProductDto`.
///
/// Immutable. Each `with*` method changes one facet, keeps the others, and
/// **resets to page 1**, because changing any filter invalidates the current
/// pagination. Only [pageAt] moves the page while keeping the rest.
///
/// There is deliberately no `copyWith`: with this many nullable fields it
/// cannot tell "leave unchanged" from "set to null" without sentinel values.
final class ProductQuery {
  const ProductQuery({
    this.page = 1,
    this.search,
    this.categoryId,
    this.minPrice,
    this.maxPrice,
    this.sort = ProductSort.newest,
  });

  final int page;
  final String? search;
  final String? categoryId;
  final double? minPrice;
  final double? maxPrice;
  final ProductSort sort;

  bool get hasPriceFilter => minPrice != null || maxPrice != null;

  ProductQuery withSearch(String? search) {
    final String? cleaned = search?.trim();
    return ProductQuery(
      search: (cleaned == null || cleaned.isEmpty) ? null : cleaned,
      categoryId: categoryId,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sort: sort,
    );
  }

  ProductQuery withCategory(String? categoryId) => ProductQuery(
    search: search,
    categoryId: categoryId,
    minPrice: minPrice,
    maxPrice: maxPrice,
    sort: sort,
  );

  ProductQuery withPriceRange(double? minPrice, double? maxPrice) =>
      ProductQuery(
        search: search,
        categoryId: categoryId,
        minPrice: minPrice,
        maxPrice: maxPrice,
        sort: sort,
      );

  ProductQuery withSort(ProductSort sort) => ProductQuery(
    search: search,
    categoryId: categoryId,
    minPrice: minPrice,
    maxPrice: maxPrice,
    sort: sort,
  );

  ProductQuery pageAt(int page) => ProductQuery(
    page: page,
    search: search,
    categoryId: categoryId,
    minPrice: minPrice,
    maxPrice: maxPrice,
    sort: sort,
  );

  /// Server defaults (`page=1`, `sort=newest`) are omitted from the wire so
  /// the request stays minimal.
  Map<String, dynamic> toQueryParameters() => <String, dynamic>{
    if (page != 1) 'page': page,
    if (search != null) 'search': search,
    if (categoryId != null) 'categoryId': categoryId,
    if (minPrice != null) 'minPrice': minPrice,
    if (maxPrice != null) 'maxPrice': maxPrice,
    if (sort != ProductSort.newest) 'sort': sort.wire,
  };

  @override
  bool operator ==(Object other) =>
      other is ProductQuery &&
      other.page == page &&
      other.search == search &&
      other.categoryId == categoryId &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.sort == sort;

  @override
  int get hashCode =>
      Object.hash(page, search, categoryId, minPrice, maxPrice, sort);
}

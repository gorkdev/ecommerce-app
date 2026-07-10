import 'package:ecommerce_app/features/catalog/domain/product_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the default query sends no parameters at all', () {
    expect(const ProductQuery().toQueryParameters(), isEmpty);
  });

  test('every non-default facet reaches the wire, sort by its API name', () {
    final ProductQuery query = const ProductQuery()
        .withSearch('head')
        .withCategory('cat_1')
        .withPriceRange(10, 250)
        .withSort(ProductSort.priceDesc)
        .pageAt(3);

    expect(query.toQueryParameters(), <String, dynamic>{
      'page': 3,
      'search': 'head',
      'categoryId': 'cat_1',
      'minPrice': 10.0,
      'maxPrice': 250.0,
      'sort': 'price_desc',
    });
  });

  test('changing a filter keeps the others but resets the page', () {
    final ProductQuery query = const ProductQuery()
        .withCategory('cat_1')
        .withPriceRange(10, null)
        .pageAt(4)
        .withSearch('mug');

    expect(query.page, 1);
    expect(query.categoryId, 'cat_1');
    expect(query.minPrice, 10);
    expect(query.search, 'mug');
  });

  test('a blank search collapses to no search filter', () {
    expect(const ProductQuery().withSearch('   ').search, isNull);
    expect(const ProductQuery().withSearch('').search, isNull);
    expect(const ProductQuery().withSearch(' mug ').search, 'mug');
  });

  test('clearing the category keeps the rest of the query', () {
    final ProductQuery query = const ProductQuery()
        .withSearch('mug')
        .withCategory('cat_1')
        .withCategory(null);

    expect(query.categoryId, isNull);
    expect(query.search, 'mug');
  });

  test('pageAt moves only the page', () {
    final ProductQuery query = const ProductQuery()
        .withSearch('mug')
        .withSort(ProductSort.priceAsc)
        .pageAt(2);

    expect(query.page, 2);
    expect(query.search, 'mug');
    expect(query.sort, ProductSort.priceAsc);
  });

  test('compares by value', () {
    expect(
      const ProductQuery().withSearch('mug').withCategory('c1'),
      const ProductQuery().withCategory('c1').withSearch('mug'),
    );
    expect(const ProductQuery(), isNot(const ProductQuery().pageAt(2)));
  });
}

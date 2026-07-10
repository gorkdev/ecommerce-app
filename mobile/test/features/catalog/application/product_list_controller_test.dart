import 'dart:async';

import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/catalog/application/product_list_controller.dart';
import 'package:ecommerce_app/features/catalog/data/catalog_repository.dart';
import 'package:ecommerce_app/features/catalog/domain/paginated.dart';
import 'package:ecommerce_app/features/catalog/domain/product.dart';
import 'package:ecommerce_app/features/catalog/domain/product_query.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

Product _product(String id) => Product(
  id: id,
  slug: id,
  name: 'Product $id',
  description: '',
  price: '10.00',
  compareAtPrice: null,
  currency: 'TRY',
  stock: 1,
  category: null,
  images: const <ProductImage>[],
);

Paginated<Product> _page(
  List<String> ids, {
  int page = 1,
  int totalPages = 1,
}) => Paginated<Product>(
  items: ids.map(_product).toList(),
  page: page,
  limit: 20,
  total: ids.length,
  totalPages: totalPages,
);

void main() {
  late MockCatalogRepository repository;

  setUpAll(() => registerFallbackValue(const ProductQuery()));

  setUp(() => repository = MockCatalogRepository());

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      // No automatic retry, matching main.dart — keeps failure tests exact.
      retry: (int retryCount, Object error) => null,
      overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads the first page with the default query on build', () async {
    when(
      () => repository.fetchProducts(any()),
    ).thenAnswer((_) async => _page(<String>['a', 'b']));

    final ProviderContainer container = makeContainer();
    final ProductListState state = await container.read(
      productListControllerProvider.future,
    );

    expect(state.products, hasLength(2));
    expect(state.hasMore, isFalse);
    verify(() => repository.fetchProducts(const ProductQuery())).called(1);
  });

  test('apply reloads from page 1 with the new query', () async {
    when(() => repository.fetchProducts(any())).thenAnswer((
      Invocation invocation,
    ) async {
      final ProductQuery query =
          invocation.positionalArguments.single as ProductQuery;
      return query.search == 'mug'
          ? _page(<String>['mug-1'])
          : _page(<String>['a', 'b']);
    });

    final ProviderContainer container = makeContainer();
    final ProductListController controller = container.read(
      productListControllerProvider.notifier,
    );
    await container.read(productListControllerProvider.future);

    await controller.apply(controller.query.withSearch('mug'));

    final ProductListState state = container
        .read(productListControllerProvider)
        .value!;
    expect(state.products.single.id, 'mug-1');
    expect(controller.query.search, 'mug');
  });

  test('applying an identical query does not refetch', () async {
    when(
      () => repository.fetchProducts(any()),
    ).thenAnswer((_) async => _page(<String>['a']));

    final ProviderContainer container = makeContainer();
    final ProductListController controller = container.read(
      productListControllerProvider.notifier,
    );
    await container.read(productListControllerProvider.future);

    await controller.apply(controller.query.withSearch(null));

    verify(() => repository.fetchProducts(any())).called(1);
  });

  test('loadMore appends the next page and updates the cursor', () async {
    when(() => repository.fetchProducts(any())).thenAnswer((
      Invocation invocation,
    ) async {
      final ProductQuery query =
          invocation.positionalArguments.single as ProductQuery;
      return query.page == 1
          ? _page(<String>['a', 'b'], totalPages: 2)
          : _page(<String>['c'], page: 2, totalPages: 2);
    });

    final ProviderContainer container = makeContainer();
    final ProductListController controller = container.read(
      productListControllerProvider.notifier,
    );
    await container.read(productListControllerProvider.future);

    await controller.loadMore();

    final ProductListState state = container
        .read(productListControllerProvider)
        .value!;
    expect(
      state.products.map((Product p) => p.id),
      <String>['a', 'b', 'c'],
    );
    expect(state.page, 2);
    expect(state.hasMore, isFalse);
    expect(state.isLoadingMore, isFalse);
  });

  test('loadMore is a no-op on the last page', () async {
    when(
      () => repository.fetchProducts(any()),
    ).thenAnswer((_) async => _page(<String>['a']));

    final ProviderContainer container = makeContainer();
    final ProductListController controller = container.read(
      productListControllerProvider.notifier,
    );
    await container.read(productListControllerProvider.future);

    await controller.loadMore();

    verify(() => repository.fetchProducts(any())).called(1);
  });

  test('concurrent loadMore calls collapse into one request', () async {
    final Completer<Paginated<Product>> pending =
        Completer<Paginated<Product>>();
    when(() => repository.fetchProducts(any())).thenAnswer((
      Invocation invocation,
    ) {
      final ProductQuery query =
          invocation.positionalArguments.single as ProductQuery;
      if (query.page == 1) {
        return Future<Paginated<Product>>.value(
          _page(<String>['a'], totalPages: 2),
        );
      }
      return pending.future;
    });

    final ProviderContainer container = makeContainer();
    final ProductListController controller = container.read(
      productListControllerProvider.notifier,
    );
    await container.read(productListControllerProvider.future);

    final Future<void> first = controller.loadMore();
    final Future<void> second = controller.loadMore();
    pending.complete(_page(<String>['b'], page: 2, totalPages: 2));
    await Future.wait(<Future<void>>[first, second]);

    // One initial fetch + exactly one page-2 fetch.
    verify(() => repository.fetchProducts(any())).called(2);
    expect(
      container.read(productListControllerProvider).value!.products,
      hasLength(2),
    );
  });

  test('a failed append keeps the grid and flags the failure', () async {
    when(() => repository.fetchProducts(any())).thenAnswer((
      Invocation invocation,
    ) async {
      final ProductQuery query =
          invocation.positionalArguments.single as ProductQuery;
      if (query.page == 1) return _page(<String>['a'], totalPages: 2);
      throw const NetworkException();
    });

    final ProviderContainer container = makeContainer();
    final ProductListController controller = container.read(
      productListControllerProvider.notifier,
    );
    await container.read(productListControllerProvider.future);

    await controller.loadMore();

    final ProductListState state = container
        .read(productListControllerProvider)
        .value!;
    expect(state.products.single.id, 'a');
    expect(state.loadMoreFailed, isTrue);
    expect(state.isLoadingMore, isFalse);
    // The next attempt clears the flag again.
    expect(state.hasMore, isTrue);
  });

  test('a stale response never overwrites a newer query', () async {
    final Completer<Paginated<Product>> slowA =
        Completer<Paginated<Product>>();
    final Completer<Paginated<Product>> fastB =
        Completer<Paginated<Product>>();
    when(() => repository.fetchProducts(any())).thenAnswer((
      Invocation invocation,
    ) {
      final ProductQuery query =
          invocation.positionalArguments.single as ProductQuery;
      return switch (query.search) {
        'aaa' => slowA.future,
        'bbb' => fastB.future,
        _ => Future<Paginated<Product>>.value(_page(<String>['initial'])),
      };
    });

    final ProviderContainer container = makeContainer();
    final ProductListController controller = container.read(
      productListControllerProvider.notifier,
    );
    await container.read(productListControllerProvider.future);

    final Future<void> first = controller.apply(
      controller.query.withSearch('aaa'),
    );
    final Future<void> second = controller.apply(
      controller.query.withSearch('bbb'),
    );

    fastB.complete(_page(<String>['b-result']));
    await second;
    // The slow response for the *older* query arrives last...
    slowA.complete(_page(<String>['a-result']));
    await first;

    // ...and must be discarded.
    expect(
      container.read(productListControllerProvider).value!.products.single.id,
      'b-result',
    );
    expect(controller.query.search, 'bbb');
  });

  test('reload re-runs the current query after a failure', () async {
    int calls = 0;
    when(() => repository.fetchProducts(any())).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw const NetworkException();
      return _page(<String>['a']);
    });

    final ProviderContainer container = makeContainer();
    final ProductListController controller = container.read(
      productListControllerProvider.notifier,
    );
    await expectLater(
      container.read(productListControllerProvider.future),
      throwsA(isA<NetworkException>()),
    );

    await controller.reload();

    expect(
      container.read(productListControllerProvider).value!.products,
      hasLength(1),
    );
  });
}

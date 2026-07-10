import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/catalog/data/catalog_repository.dart';
import 'package:ecommerce_app/features/catalog/domain/category.dart';
import 'package:ecommerce_app/features/catalog/domain/paginated.dart';
import 'package:ecommerce_app/features/catalog/domain/product.dart';
import 'package:ecommerce_app/features/catalog/domain/product_query.dart';
import 'package:ecommerce_app/features/catalog/presentation/catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

Product _product(String id, String name) => Product(
  id: id,
  slug: id,
  name: name,
  description: '',
  price: '49.90',
  compareAtPrice: null,
  currency: 'TRY',
  stock: 5,
  category: null,
  images: const <ProductImage>[],
);

Paginated<Product> _page(List<Product> items) => Paginated<Product>(
  items: items,
  page: 1,
  limit: 20,
  total: items.length,
  totalPages: 1,
);

const List<Category> _categories = <Category>[
  Category(
    id: 'cat_audio',
    slug: 'audio',
    name: 'Audio',
    parentId: null,
    children: <Category>[],
  ),
];

void main() {
  late MockCatalogRepository repository;

  setUpAll(() => registerFallbackValue(const ProductQuery()));

  setUp(() {
    repository = MockCatalogRepository();
    when(
      () => repository.fetchCategories(),
    ).thenAnswer((_) async => _categories);
  });

  Future<void> pumpCatalog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry is off, otherwise
        // pumpAndSettle's fake clock fires the retry timers and the error
        // states under test heal themselves mid-test.
        retry: (int retryCount, Object error) => null,
        overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: CatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<ProductQuery> capturedQueries() =>
      verify(() => repository.fetchProducts(captureAny()))
          .captured
          .cast<ProductQuery>();

  testWidgets('renders the grid and the category chips', (
    WidgetTester tester,
  ) async {
    when(() => repository.fetchProducts(any())).thenAnswer(
      (_) async => _page(<Product>[
        _product('p1', 'Ceramic Mug'),
        _product('p2', 'Steel Bottle'),
      ]),
    );

    await pumpCatalog(tester);

    expect(find.text('Ceramic Mug'), findsOneWidget);
    expect(find.text('Steel Bottle'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Audio'), findsOneWidget);
  });

  testWidgets('debounces typing and applies the search once', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProducts(any()),
    ).thenAnswer((_) async => _page(<Product>[_product('p1', 'Mug')]));

    await pumpCatalog(tester);

    await tester.enterText(find.byType(TextField).first, 'm');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).first, 'mug');
    // Not yet: the debounce window is still open.
    await tester.pump(const Duration(milliseconds: 200));

    verify(() => repository.fetchProducts(any())).called(1);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final List<ProductQuery> queries = capturedQueries();
    expect(queries, hasLength(1));
    expect(queries.single.search, 'mug');
  });

  testWidgets('shows the empty state when nothing matches', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProducts(any()),
    ).thenAnswer((_) async => _page(const <Product>[]));

    await pumpCatalog(tester);

    expect(find.text('No products found'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry that refetches', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    when(() => repository.fetchProducts(any())).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw const NetworkException();
      return _page(<Product>[_product('p1', 'Ceramic Mug')]);
    });

    await pumpCatalog(tester);

    expect(find.text('No connection to the server.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Ceramic Mug'), findsOneWidget);
  });

  testWidgets('tapping a category chip filters by that category', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProducts(any()),
    ).thenAnswer((_) async => _page(<Product>[_product('p1', 'Headset')]));

    await pumpCatalog(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Audio'));
    await tester.pumpAndSettle();

    final List<ProductQuery> queries = capturedQueries();
    expect(queries, hasLength(2));
    expect(queries.last.categoryId, 'cat_audio');
  });

  testWidgets('the sort menu applies the chosen order', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProducts(any()),
    ).thenAnswer((_) async => _page(<Product>[_product('p1', 'Mug')]));

    await pumpCatalog(tester);

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    // Tap the menu item itself: the Text's own center can fall outside the
    // item's hit-test area.
    await tester.tap(
      find.ancestor(
        of: find.text('Price: low to high'),
        matching: find.byType(CheckedPopupMenuItem<ProductSort>),
      ),
    );
    await tester.pumpAndSettle();

    final List<ProductQuery> queries = capturedQueries();
    expect(queries, hasLength(2));
    expect(queries.last.sort, ProductSort.priceAsc);
  });
}

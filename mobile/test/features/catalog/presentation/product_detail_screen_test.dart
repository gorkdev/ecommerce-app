import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/catalog/data/catalog_repository.dart';
import 'package:ecommerce_app/features/catalog/domain/product.dart';
import 'package:ecommerce_app/features/catalog/presentation/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

const Product _headphones = Product(
  id: 'prd_1',
  slug: 'wireless-headphones',
  name: 'Wireless Headphones',
  description: 'Crisp sound, all-day battery.',
  price: '75.00',
  compareAtPrice: '100.00',
  currency: 'TRY',
  stock: 3,
  category: CategoryRef(id: 'cat_1', slug: 'audio', name: 'Audio'),
  images: <ProductImage>[],
);

void main() {
  late MockCatalogRepository repository;

  setUp(() => repository = MockCatalogRepository());

  Future<void> pumpDetail(WidgetTester tester) async {
    // A portrait surface, like a real phone. On the default 800x600 test
    // surface the square gallery alone fills the viewport and the lazy
    // ListView never builds the body below it.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry is off, otherwise
        // pumpAndSettle's fake clock fires the retry timers and the error
        // states under test heal themselves mid-test.
        retry: (int retryCount, Object error) => null,
        overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: ProductDetailScreen(slug: 'wireless-headphones'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders name, pricing, stock and description', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProduct('wireless-headphones'),
    ).thenAnswer((_) async => _headphones);

    await pumpDetail(tester);

    // Name shows in the app bar and in the body.
    expect(find.text('Wireless Headphones'), findsNWidgets(2));
    expect(find.text('₺75.00'), findsOneWidget);
    expect(find.text('AUDIO'), findsOneWidget);
    expect(find.text('In stock'), findsOneWidget);
    expect(find.text('Crisp sound, all-day battery.'), findsOneWidget);
  });

  testWidgets('shows the discount: struck-through price and badge', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProduct('wireless-headphones'),
    ).thenAnswer((_) async => _headphones);

    await pumpDetail(tester);

    expect(find.text('-25%'), findsOneWidget);
    final Text compareAt = tester.widget<Text>(find.text('₺100.00'));
    expect(compareAt.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('flags an out-of-stock product', (WidgetTester tester) async {
    when(() => repository.fetchProduct('wireless-headphones')).thenAnswer(
      (_) async => const Product(
        id: 'prd_1',
        slug: 'wireless-headphones',
        name: 'Wireless Headphones',
        description: 'Crisp sound.',
        price: '75.00',
        compareAtPrice: null,
        currency: 'TRY',
        stock: 0,
        category: null,
        images: <ProductImage>[],
      ),
    );

    await pumpDetail(tester);

    expect(find.text('Out of stock'), findsOneWidget);
  });

  testWidgets('a vanished product reads as gone, with no retry', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProduct('wireless-headphones'),
    ).thenThrow(const ApiStatusException(404, 'Product not found'));

    await pumpDetail(tester);

    expect(find.text('This product is no longer available.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a transient failure offers a retry that refetches', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    when(() => repository.fetchProduct('wireless-headphones')).thenAnswer((
      _,
    ) async {
      calls++;
      if (calls == 1) throw const NetworkException();
      return _headphones;
    });

    await pumpDetail(tester);

    expect(find.text('No connection to the server.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Wireless Headphones'), findsNWidgets(2));
  });
}

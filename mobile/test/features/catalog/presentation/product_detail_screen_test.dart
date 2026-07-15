import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/cart/data/cart_repository.dart';
import 'package:ecommerce_app/features/cart/domain/cart.dart';
import 'package:ecommerce_app/features/catalog/data/catalog_repository.dart';
import 'package:ecommerce_app/features/catalog/domain/product.dart';
import 'package:ecommerce_app/features/catalog/domain/product_summary.dart';
import 'package:ecommerce_app/features/catalog/presentation/product_detail_screen.dart';
import 'package:ecommerce_app/features/favorites/data/favorites_repository.dart';
import 'package:ecommerce_app/features/favorites/domain/favorite.dart';
import 'package:ecommerce_app/features/reviews/data/reviews_repository.dart';
import 'package:ecommerce_app/features/reviews/domain/review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/test_app.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

class MockCartRepository extends Mock implements CartRepository {}

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

class MockReviewsRepository extends Mock implements ReviewsRepository {}

const ProductReviews _noReviews = ProductReviews(
  items: <Review>[],
  summary: RatingSummary(
    average: 0,
    count: 0,
    distribution: <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  ),
);

const Cart _emptyCart = Cart(
  id: 'cart_1',
  items: <CartItem>[],
  summary: CartSummary(itemCount: 0, subtotal: '0.00', currency: 'TRY'),
);

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
  late MockCartRepository cartRepository;
  late MockFavoritesRepository favoritesRepository;
  late MockReviewsRepository reviewsRepository;

  setUp(() {
    repository = MockCatalogRepository();
    cartRepository = MockCartRepository();
    when(() => cartRepository.fetchCart()).thenAnswer((_) async => _emptyCart);
    favoritesRepository = MockFavoritesRepository();
    when(
      () => favoritesRepository.list(),
    ).thenAnswer((_) async => const <Favorite>[]);
    reviewsRepository = MockReviewsRepository();
    when(
      () => reviewsRepository.fetchForProduct(any()),
    ).thenAnswer((_) async => _noReviews);
  });

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
        overrides: [
          catalogRepositoryProvider.overrideWithValue(repository),
          cartRepositoryProvider.overrideWithValue(cartRepository),
          favoritesRepositoryProvider.overrideWithValue(favoritesRepository),
          reviewsRepositoryProvider.overrideWithValue(reviewsRepository),
        ],
        child: testApp(
          home: const ProductDetailScreen(slug: 'wireless-headphones'),
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

    expect(find.text('Wireless Headphones'), findsOneWidget);
    // Once in the price row, once on the sticky bottom bar.
    expect(find.text('₺75.00'), findsNWidgets(2));
    expect(find.text('AUDIO'), findsOneWidget);
    // Three units left triggers the low-stock nudge.
    expect(find.text('Only 3 left in stock'), findsOneWidget);
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

    // Once in the stock row, once on the disabled cart button.
    expect(find.text('Out of stock'), findsNWidgets(2));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('adds the product to the cart from the bottom bar', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProduct('wireless-headphones'),
    ).thenAnswer((_) async => _headphones);
    when(
      () => cartRepository.addItem(
        productId: any(named: 'productId'),
        quantity: any(named: 'quantity'),
      ),
    ).thenAnswer((_) async => _emptyCart);

    await pumpDetail(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add to cart'));
    await tester.pumpAndSettle();

    verify(
      () => cartRepository.addItem(productId: 'prd_1', quantity: 1),
    ).called(1);
    expect(find.text('Added to cart'), findsOneWidget);
  });

  testWidgets('surfaces the stock-limit message when adding fails', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProduct('wireless-headphones'),
    ).thenAnswer((_) async => _headphones);
    when(
      () => cartRepository.addItem(
        productId: any(named: 'productId'),
        quantity: any(named: 'quantity'),
      ),
    ).thenThrow(
      const ApiStatusException(
        400,
        'Only 3 unit(s) of this product are in stock',
      ),
    );

    await pumpDetail(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add to cart'));
    await tester.pumpAndSettle();

    expect(
      find.text('Only 3 unit(s) of this product are in stock'),
      findsOneWidget,
    );
  });

  testWidgets('the app bar heart toggles the favorite', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProduct('wireless-headphones'),
    ).thenAnswer((_) async => _headphones);
    when(() => favoritesRepository.add('prd_1')).thenAnswer(
      (_) async => const <Favorite>[
        Favorite(
          id: 'fav_1',
          productId: 'prd_1',
          product: ProductSummary(
            id: 'prd_1',
            slug: 'wireless-headphones',
            name: 'Wireless Headphones',
            price: '75.00',
            currency: 'TRY',
            stock: 3,
            isActive: true,
            imageUrl: null,
          ),
        ),
      ],
    );

    await pumpDetail(tester);

    expect(find.byIcon(Icons.favorite_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_outline));
    await tester.pumpAndSettle();

    verify(() => favoritesRepository.add('prd_1')).called(1);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('summarizes the rating and links to the reviews', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProduct('wireless-headphones'),
    ).thenAnswer((_) async => _headphones);
    when(() => reviewsRepository.fetchForProduct('prd_1')).thenAnswer(
      (_) async => const ProductReviews(
        items: <Review>[],
        summary: RatingSummary(
          average: 4.2,
          count: 12,
          distribution: <int, int>{1: 0, 2: 1, 3: 1, 4: 4, 5: 6},
        ),
      ),
    );

    await pumpDetail(tester);

    // The rating chip: ★ 4.2 (12).
    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('(12)'), findsOneWidget);
  });

  testWidgets('a review-less product shows a zero rating chip', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchProduct('wireless-headphones'),
    ).thenAnswer((_) async => _headphones);

    await pumpDetail(tester);

    // The invite to write the first review lives on the reviews screen;
    // the detail page just reports the honest zero.
    expect(find.text('0.0'), findsOneWidget);
    expect(find.text('(0)'), findsOneWidget);
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

    expect(find.text('Wireless Headphones'), findsOneWidget);
  });
}

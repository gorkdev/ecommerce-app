import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/catalog/domain/product_summary.dart';
import 'package:ecommerce_app/features/favorites/data/favorites_repository.dart';
import 'package:ecommerce_app/features/favorites/domain/favorite.dart';
import 'package:ecommerce_app/features/favorites/presentation/favorites_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/test_app.dart';

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

const Favorite _savedMug = Favorite(
  id: 'fav_1',
  productId: 'prd_1',
  product: ProductSummary(
    id: 'prd_1',
    slug: 'ceramic-mug',
    name: 'Ceramic Mug',
    price: '49.90',
    currency: 'TRY',
    stock: 0,
    isActive: true,
    imageUrl: null,
  ),
);

void main() {
  late MockFavoritesRepository repository;

  setUp(() => repository = MockFavoritesRepository());

  Future<void> pumpFavorites(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry stays off in tests.
        retry: (int retryCount, Object error) => null,
        overrides: [favoritesRepositoryProvider.overrideWithValue(repository)],
        child: testApp(home: const FavoritesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders saved products with price and stock warning', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Favorite>[_savedMug]);

    await pumpFavorites(tester);

    expect(find.text('Ceramic Mug'), findsOneWidget);
    expect(find.text('₺49.90'), findsOneWidget);
    expect(find.text('Out of stock'), findsOneWidget);
  });

  testWidgets('the heart un-saves and the row disappears', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Favorite>[_savedMug]);
    when(() => repository.remove('prd_1')).thenAnswer((_) async {});

    await pumpFavorites(tester);

    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    verify(() => repository.remove('prd_1')).called(1);
    expect(find.text('Ceramic Mug'), findsNothing);
    expect(find.text('Nothing saved yet'), findsOneWidget);
  });

  testWidgets('a failed un-save brings the row back and reports it', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Favorite>[_savedMug]);
    when(() => repository.remove('prd_1')).thenThrow(const NetworkException());

    await pumpFavorites(tester);

    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(find.text('Ceramic Mug'), findsOneWidget);
    expect(find.text('No connection to the server.'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing is saved', (
    WidgetTester tester,
  ) async {
    when(() => repository.list()).thenAnswer((_) async => const <Favorite>[]);

    await pumpFavorites(tester);

    expect(find.text('Nothing saved yet'), findsOneWidget);
  });
}

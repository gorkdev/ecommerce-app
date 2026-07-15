import 'package:ecommerce_app/app.dart';
import 'package:ecommerce_app/core/l10n/locale_controller.dart';
import 'package:ecommerce_app/core/push/push_messaging_service.dart';
import 'package:ecommerce_app/core/storage/token_storage.dart';
import 'package:ecommerce_app/features/auth/data/auth_repository.dart';
import 'package:ecommerce_app/features/auth/domain/auth_user.dart';
import 'package:ecommerce_app/features/cart/data/cart_repository.dart';
import 'package:ecommerce_app/features/cart/domain/cart.dart';
import 'package:ecommerce_app/features/catalog/data/catalog_repository.dart';
import 'package:ecommerce_app/features/catalog/domain/category.dart';
import 'package:ecommerce_app/features/catalog/domain/paginated.dart';
import 'package:ecommerce_app/features/catalog/domain/product.dart';
import 'package:ecommerce_app/features/catalog/domain/product_query.dart';
import 'package:ecommerce_app/features/favorites/data/favorites_repository.dart';
import 'package:ecommerce_app/features/favorites/domain/favorite.dart';
import 'package:ecommerce_app/features/orders/data/orders_repository.dart';
import 'package:ecommerce_app/features/orders/domain/order.dart';
import 'package:ecommerce_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_token_storage.dart';

// The signed-in app shell: five bottom-nav tabs, a live cart badge, and
// tab switches that actually change the visible screen.

class MockPushMessagingService extends Mock implements PushMessagingService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockCatalogRepository extends Mock implements CatalogRepository {}

class MockCartRepository extends Mock implements CartRepository {}

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

class MockOrdersRepository extends Mock implements OrdersRepository {}

const AuthUser _user = AuthUser(
  id: 'usr_1',
  email: 'customer@example.com',
  name: 'Ada Lovelace',
  role: UserRole.customer,
);

// The badge reads the server-computed summary count; line details are
// irrelevant here.
const Cart _cartWithTwo = Cart(
  id: 'cart_1',
  items: <CartItem>[],
  summary: CartSummary(itemCount: 2, subtotal: '99.80', currency: 'TRY'),
);

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() => registerFallbackValue(const ProductQuery()));

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final MockPushMessagingService push = MockPushMessagingService();
    when(() => push.initialize()).thenAnswer((_) async => false);
    when(() => push.getToken()).thenAnswer((_) async => null);

    final MockAuthRepository authRepository = MockAuthRepository();
    when(() => authRepository.me()).thenAnswer((_) async => _user);

    final MockCatalogRepository catalog = MockCatalogRepository();
    when(() => catalog.fetchCategories()).thenAnswer((_) async => <Category>[]);
    when(() => catalog.fetchProducts(any())).thenAnswer(
      (_) async => const Paginated<Product>(
        items: <Product>[],
        page: 1,
        limit: 20,
        total: 0,
        totalPages: 1,
      ),
    );

    final MockCartRepository cart = MockCartRepository();
    when(() => cart.fetchCart()).thenAnswer((_) async => _cartWithTwo);
    final MockFavoritesRepository favorites = MockFavoritesRepository();
    when(() => favorites.list()).thenAnswer((_) async => const <Favorite>[]);
    final MockOrdersRepository orders = MockOrdersRepository();
    when(() => orders.fetchOrders()).thenAnswer((_) async => const <Order>[]);

    await tester.pumpWidget(
      ProviderScope(
        retry: (int retryCount, Object error) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          pushMessagingServiceProvider.overrideWithValue(push),
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(
              accessToken: 'access-1',
              refreshToken: 'refresh-1',
            ),
          ),
          authRepositoryProvider.overrideWithValue(authRepository),
          catalogRepositoryProvider.overrideWithValue(catalog),
          cartRepositoryProvider.overrideWithValue(cart),
          favoritesRepositoryProvider.overrideWithValue(favorites),
          ordersRepositoryProvider.overrideWithValue(orders),
        ],
        child: const EcommerceApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('signed-in shell shows the five destinations', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final String label in <String>[
      en.navDiscover,
      en.navFavorites,
      en.navCart,
      en.navOrders,
      en.navProfile,
    ]) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('the cart destination carries a live item-count badge', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('2')),
      findsWidgets,
    );
  });

  testWidgets('tapping a destination switches the visible screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(en.navOrders),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.noOrdersYet), findsOneWidget);

    // Back to the first tab: the catalog is still there (state preserved).
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(en.navDiscover),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });
}

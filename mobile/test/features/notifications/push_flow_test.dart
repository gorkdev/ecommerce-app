import 'dart:async';

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
import 'package:ecommerce_app/features/notifications/data/notifications_repository.dart';
import 'package:ecommerce_app/features/orders/data/orders_repository.dart';
import 'package:ecommerce_app/features/orders/domain/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_token_storage.dart';

// The whole app, booted for real (splash -> session restore -> catalog),
// with only the outer edges mocked. Proves the push wiring end to end:
// a tray tap deep-links to the order, a foreground message becomes a
// snackbar whose action navigates.

class MockPushMessagingService extends Mock implements PushMessagingService {}

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

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

const Cart _emptyCart = Cart(
  id: 'cart_1',
  items: <CartItem>[],
  summary: CartSummary(itemCount: 0, subtotal: '0.00', currency: 'TRY'),
);

Order _order() => Order(
  id: 'ord_1',
  status: OrderStatus.shipped,
  subtotal: '114.80',
  discountTotal: '0.00',
  total: '114.80',
  currency: 'TRY',
  createdAt: DateTime(2026, 7, 11, 9, 30),
  items: const <OrderItem>[
    OrderItem(
      id: 'oi_1',
      productId: 'prd_1',
      name: 'Ceramic Mug',
      unitPrice: '49.90',
      quantity: 2,
      productSlug: 'ceramic-mug',
      imageUrl: null,
    ),
  ],
  coupon: null,
);

PushMessage _shippedMessage() => const PushMessage(
  title: 'Order shipped',
  body: 'Your order is on its way.',
  data: <String, String>{
    'type': 'order-status',
    'orderId': 'ord_1',
    'status': 'SHIPPED',
  },
);

void main() {
  late MockPushMessagingService service;
  late StreamController<PushMessage> opened;
  late StreamController<PushMessage> foreground;

  setUpAll(() => registerFallbackValue(const ProductQuery()));

  setUp(() {
    service = MockPushMessagingService();
    opened = StreamController<PushMessage>.broadcast();
    foreground = StreamController<PushMessage>.broadcast();
    when(() => service.initialize()).thenAnswer((_) async => true);
    when(() => service.getToken()).thenAnswer((_) async => 'fcm-token-1');
    when(
      () => service.tokenRefreshStream(),
    ).thenAnswer((_) => const Stream<String>.empty());
    when(() => service.openedMessages()).thenAnswer((_) => opened.stream);
    when(
      () => service.foregroundMessages(),
    ).thenAnswer((_) => foreground.stream);
    when(() => service.initialMessage()).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await opened.close();
    await foreground.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    // Portrait, like a real phone: the order detail page is tall.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final MockAuthRepository authRepository = MockAuthRepository();
    when(() => authRepository.me()).thenAnswer((_) async => _user);

    final MockNotificationsRepository notifications =
        MockNotificationsRepository();
    when(
      () => notifications.registerDeviceToken(
        token: any(named: 'token'),
        platform: any(named: 'platform'),
        locale: any(named: 'locale'),
      ),
    ).thenAnswer((_) async {});

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
    when(() => cart.fetchCart()).thenAnswer((_) async => _emptyCart);
    final MockFavoritesRepository favorites = MockFavoritesRepository();
    when(() => favorites.list()).thenAnswer((_) async => const <Favorite>[]);

    final MockOrdersRepository orders = MockOrdersRepository();
    when(() => orders.fetchOrder('ord_1')).thenAnswer((_) async => _order());

    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry stays off in tests.
        retry: (int retryCount, Object error) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          pushMessagingServiceProvider.overrideWithValue(service),
          notificationsRepositoryProvider.overrideWithValue(notifications),
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

  testWidgets('a tray-notification tap deep-links to the order', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    opened.add(_shippedMessage());
    await tester.pumpAndSettle();

    expect(find.text('Order #ORD_1'), findsOneWidget);
    expect(find.text('Ceramic Mug'), findsOneWidget);
  });

  testWidgets('a foreground message becomes a snackbar that can navigate', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    foreground.add(_shippedMessage());
    await tester.pumpAndSettle();

    // The banner shows the copy exactly as the server rendered it.
    expect(
      find.text('Order shipped — Your order is on its way.'),
      findsOneWidget,
    );

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text('Order #ORD_1'), findsOneWidget);
  });

  testWidgets('a tap on a cold start lands on the order after restore', (
    WidgetTester tester,
  ) async {
    when(
      () => service.initialMessage(),
    ).thenAnswer((_) async => _shippedMessage());

    await pumpApp(tester);

    expect(find.text('Order #ORD_1'), findsOneWidget);
  });

  testWidgets('messages without order data change nothing', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    opened.add(
      const PushMessage(title: 'Hello', data: <String, String>{'type': 'promo'}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order #ORD_1'), findsNothing);
  });
}

import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/orders/data/orders_repository.dart';
import 'package:ecommerce_app/features/orders/domain/order.dart';
import 'package:ecommerce_app/features/orders/presentation/orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrdersRepository extends Mock implements OrdersRepository {}

Order _order() => Order(
  id: 'ord_1',
  status: OrderStatus.paid,
  subtotal: '114.80',
  discountTotal: '0.00',
  total: '114.80',
  currency: 'TRY',
  // A local timestamp keeps the rendered date machine-independent.
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
    OrderItem(
      id: 'oi_2',
      productId: 'prd_2',
      name: 'Steel Bottle',
      unitPrice: '15.00',
      quantity: 1,
      productSlug: 'steel-bottle',
      imageUrl: null,
    ),
  ],
  coupon: null,
);

void main() {
  late MockOrdersRepository repository;

  setUp(() => repository = MockOrdersRepository());

  Future<void> pumpOrders(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry stays off in tests.
        retry: (int retryCount, Object error) => null,
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a card per order with the essentials', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchOrders(),
    ).thenAnswer((_) async => <Order>[_order()]);

    await pumpOrders(tester);

    expect(find.text('Order #ORD_1'), findsOneWidget);
    expect(find.text('Jul 11, 2026'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('₺114.80'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('shows the empty state before the first purchase', (
    WidgetTester tester,
  ) async {
    when(() => repository.fetchOrders()).thenAnswer((_) async => <Order>[]);

    await pumpOrders(tester);

    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.text('Browse products'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry that refetches', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    when(() => repository.fetchOrders()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw const NetworkException();
      return <Order>[_order()];
    });

    await pumpOrders(tester);

    expect(find.text('No connection to the server.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Order #ORD_1'), findsOneWidget);
    expect(calls, 2);
  });
}

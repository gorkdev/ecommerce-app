import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/orders/data/orders_repository.dart';
import 'package:ecommerce_app/features/orders/domain/order.dart';
import 'package:ecommerce_app/features/orders/presentation/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/test_app.dart';

class MockOrdersRepository extends Mock implements OrdersRepository {}

Order _order({OrderStatus status = OrderStatus.paid}) => Order(
  id: 'ord_1',
  status: status,
  subtotal: '114.80',
  discountTotal: '10.00',
  total: '104.80',
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
  ],
  coupon: const OrderCoupon(id: 'cpn_1', code: 'SAVE10', type: 'FIXED'),
);

void main() {
  late MockOrdersRepository repository;

  setUp(() => repository = MockOrdersRepository());

  Future<void> pumpDetail(WidgetTester tester) async {
    // Portrait, like a real phone: timeline, items and totals must all fit.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry stays off in tests.
        retry: (int retryCount, Object error) => null,
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
        child: testApp(home: const OrderDetailScreen(orderId: 'ord_1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the header, items and charged totals', (
    WidgetTester tester,
  ) async {
    when(() => repository.fetchOrder('ord_1')).thenAnswer((_) async => _order());

    await pumpDetail(tester);

    expect(find.text('Order #ORD_1'), findsOneWidget);
    expect(find.text('Placed Jul 11, 2026 09:30'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Ceramic Mug'), findsOneWidget);
    expect(find.text('2 × ₺49.90'), findsOneWidget);
    expect(find.text('₺99.80'), findsOneWidget); // display-only line total
    expect(find.text('₺114.80'), findsOneWidget); // subtotal as charged
    expect(find.text('Discount (SAVE10)'), findsOneWidget);
    expect(find.text('−₺10.00'), findsOneWidget);
    expect(find.text('₺104.80'), findsOneWidget); // total as charged
  });

  testWidgets('the timeline marks progress up to the current status', (
    WidgetTester tester,
  ) async {
    when(() => repository.fetchOrder('ord_1')).thenAnswer((_) async => _order());

    await pumpDetail(tester);

    // PAID: placed + payment confirmed are done, the rest is still ahead.
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
    expect(find.text('Payment confirmed'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
  });

  testWidgets('a cancelled order shows a banner instead of the timeline', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchOrder('ord_1'),
    ).thenAnswer((_) async => _order(status: OrderStatus.cancelled));

    await pumpDetail(tester);

    expect(find.text('This order was cancelled.'), findsOneWidget);
    expect(find.text('Payment confirmed'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('a 404 is final: server message, no retry', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchOrder('ord_1'),
    ).thenThrow(const ApiStatusException(404, 'Order not found'));

    await pumpDetail(tester);

    expect(find.text('Order not found'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a network failure offers a retry that refetches', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    when(() => repository.fetchOrder('ord_1')).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw const NetworkException();
      return _order();
    });

    await pumpDetail(tester);

    expect(find.text('No connection to the server.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Order #ORD_1'), findsOneWidget);
    expect(calls, 2);
  });
}

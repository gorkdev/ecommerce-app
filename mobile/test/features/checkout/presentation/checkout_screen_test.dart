import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/cart/data/cart_repository.dart';
import 'package:ecommerce_app/features/cart/domain/cart.dart';
import 'package:ecommerce_app/features/catalog/domain/product_summary.dart';
import 'package:ecommerce_app/features/checkout/data/checkout_repository.dart';
import 'package:ecommerce_app/features/checkout/data/payment_sheet_service.dart';
import 'package:ecommerce_app/features/checkout/domain/checkout_session.dart';
import 'package:ecommerce_app/features/checkout/domain/coupon_quote.dart';
import 'package:ecommerce_app/features/checkout/presentation/checkout_screen.dart';
import 'package:ecommerce_app/features/orders/domain/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCartRepository extends Mock implements CartRepository {}

class MockCheckoutRepository extends Mock implements CheckoutRepository {}

class MockPaymentSheetService extends Mock implements PaymentSheetService {}

const ProductSummary _mug = ProductSummary(
  id: 'prd_1',
  slug: 'ceramic-mug',
  name: 'Ceramic Mug',
  price: '49.90',
  currency: 'TRY',
  stock: 10,
  isActive: true,
  imageUrl: null,
);

const ProductSummary _bottle = ProductSummary(
  id: 'prd_2',
  slug: 'steel-bottle',
  name: 'Steel Bottle',
  price: '15.00',
  currency: 'TRY',
  stock: 5,
  isActive: true,
  imageUrl: null,
);

const Cart _fullCart = Cart(
  id: 'cart_1',
  items: <CartItem>[
    CartItem(id: 'ci_1', productId: 'prd_1', quantity: 2, product: _mug),
    CartItem(id: 'ci_2', productId: 'prd_2', quantity: 1, product: _bottle),
  ],
  summary: CartSummary(itemCount: 3, subtotal: '114.80', currency: 'TRY'),
);

const Cart _emptyCart = Cart(
  id: 'cart_1',
  items: <CartItem>[],
  summary: CartSummary(itemCount: 0, subtotal: '0.00', currency: 'TRY'),
);

const CouponQuote _quote = CouponQuote(
  code: 'SAVE10',
  type: 'FIXED',
  currency: 'TRY',
  subtotal: '114.80',
  discount: '10.00',
  total: '104.80',
);

Order _order() => Order(
  id: 'ord_1',
  status: OrderStatus.pending,
  subtotal: '114.80',
  discountTotal: '0.00',
  total: '114.80',
  currency: 'TRY',
  createdAt: DateTime.utc(2026, 7, 11),
  items: const <OrderItem>[],
  coupon: null,
);

void main() {
  late MockCartRepository cartRepository;
  late MockCheckoutRepository checkoutRepository;
  late MockPaymentSheetService sheet;

  setUp(() {
    cartRepository = MockCartRepository();
    checkoutRepository = MockCheckoutRepository();
    sheet = MockPaymentSheetService();
    when(() => cartRepository.fetchCart()).thenAnswer((_) async => _fullCart);
  });

  Future<void> pumpCheckout(WidgetTester tester) async {
    // Portrait, like a real phone.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry stays off in tests.
        retry: (int retryCount, Object error) => null,
        overrides: [
          cartRepositoryProvider.overrideWithValue(cartRepository),
          checkoutRepositoryProvider.overrideWithValue(checkoutRepository),
          paymentSheetServiceProvider.overrideWithValue(sheet),
        ],
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the lines and the server totals', (
    WidgetTester tester,
  ) async {
    await pumpCheckout(tester);

    expect(find.text('Ceramic Mug'), findsOneWidget);
    expect(find.text('2×'), findsOneWidget);
    expect(find.text('₺99.80'), findsOneWidget); // 49.90 × 2 line total
    // Subtotal and total rows agree while no coupon is applied.
    expect(find.text('₺114.80'), findsNWidgets(2));
    expect(find.text('Pay ₺114.80'), findsOneWidget);
  });

  testWidgets('applying a coupon shows the discount and the new total', (
    WidgetTester tester,
  ) async {
    when(
      () => checkoutRepository.previewCoupon(any()),
    ).thenAnswer((_) async => _quote);

    await pumpCheckout(tester);

    await tester.enterText(find.byType(TextField), 'save10');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    verify(() => checkoutRepository.previewCoupon('save10')).called(1);
    expect(find.text('Discount (SAVE10)'), findsOneWidget);
    expect(find.text('−₺10.00'), findsOneWidget);
    expect(find.text('Pay ₺104.80'), findsOneWidget);

    // Removing the coupon restores the undiscounted total.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Discount (SAVE10)'), findsNothing);
    expect(find.text('Pay ₺114.80'), findsOneWidget);
  });

  testWidgets('a rejected coupon surfaces the server message', (
    WidgetTester tester,
  ) async {
    when(
      () => checkoutRepository.previewCoupon(any()),
    ).thenThrow(const ApiStatusException(400, 'Coupon has expired'));

    await pumpCheckout(tester);

    await tester.enterText(find.byType(TextField), 'OLD10');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Coupon has expired'), findsOneWidget);
    expect(find.textContaining('Discount'), findsNothing);
  });

  testWidgets('paying walks through to the success view', (
    WidgetTester tester,
  ) async {
    when(
      () => checkoutRepository.placeOrder(
        couponCode: any(named: 'couponCode'),
      ),
    ).thenAnswer(
      (_) async => CheckoutSession(order: _order(), clientSecret: 'secret_1'),
    );
    when(
      () => sheet.present(clientSecret: any(named: 'clientSecret')),
    ).thenAnswer((_) async => PaymentSheetOutcome.completed);

    await pumpCheckout(tester);

    await tester.tap(find.text('Pay ₺114.80'));
    await tester.pumpAndSettle();

    verify(() => checkoutRepository.placeOrder(couponCode: null)).called(1);
    verify(() => sheet.present(clientSecret: 'secret_1')).called(1);
    expect(find.text('Payment received'), findsOneWidget);
    expect(find.textContaining('Order #ORD_1'), findsOneWidget);
    expect(find.text('Continue shopping'), findsOneWidget);
  });

  testWidgets('a cancelled sheet parks the payment with a retry', (
    WidgetTester tester,
  ) async {
    when(
      () => checkoutRepository.placeOrder(
        couponCode: any(named: 'couponCode'),
      ),
    ).thenAnswer(
      (_) async => CheckoutSession(order: _order(), clientSecret: 'secret_1'),
    );
    final List<PaymentSheetOutcome> outcomes = <PaymentSheetOutcome>[
      PaymentSheetOutcome.cancelled,
      PaymentSheetOutcome.completed,
    ];
    when(
      () => sheet.present(clientSecret: any(named: 'clientSecret')),
    ).thenAnswer((_) async => outcomes.removeAt(0));

    await pumpCheckout(tester);

    await tester.tap(find.text('Pay ₺114.80'));
    await tester.pumpAndSettle();

    expect(find.text('Payment not completed'), findsOneWidget);

    // Retrying confirms the same PaymentIntent; no second order is placed.
    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    verify(
      () => checkoutRepository.placeOrder(couponCode: any(named: 'couponCode')),
    ).called(1);
    verify(() => sheet.present(clientSecret: 'secret_1')).called(2);
    expect(find.text('Payment received'), findsOneWidget);
  });

  testWidgets('a rejected checkout shows the message and stays put', (
    WidgetTester tester,
  ) async {
    when(
      () => checkoutRepository.placeOrder(
        couponCode: any(named: 'couponCode'),
      ),
    ).thenThrow(
      const ApiStatusException(400, 'Not enough stock for "Ceramic Mug"'),
    );

    await pumpCheckout(tester);

    await tester.tap(find.text('Pay ₺114.80'));
    await tester.pumpAndSettle();

    expect(
      find.text('Not enough stock for "Ceramic Mug"'),
      findsOneWidget,
    );
    expect(find.text('Pay ₺114.80'), findsOneWidget);
    verifyNever(() => sheet.present(clientSecret: any(named: 'clientSecret')));
  });

  testWidgets('an empty cart cannot check out', (WidgetTester tester) async {
    when(() => cartRepository.fetchCart()).thenAnswer((_) async => _emptyCart);

    await pumpCheckout(tester);

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.textContaining('Pay'), findsNothing);
  });
}

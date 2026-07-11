import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/cart/application/cart_controller.dart';
import 'package:ecommerce_app/features/cart/data/cart_repository.dart';
import 'package:ecommerce_app/features/cart/domain/cart.dart';
import 'package:ecommerce_app/features/checkout/application/checkout_controller.dart';
import 'package:ecommerce_app/features/checkout/data/checkout_repository.dart';
import 'package:ecommerce_app/features/checkout/data/payment_sheet_service.dart';
import 'package:ecommerce_app/features/checkout/domain/checkout_session.dart';
import 'package:ecommerce_app/features/checkout/domain/coupon_quote.dart';
import 'package:ecommerce_app/features/orders/domain/order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCheckoutRepository extends Mock implements CheckoutRepository {}

class MockPaymentSheetService extends Mock implements PaymentSheetService {}

class MockCartRepository extends Mock implements CartRepository {}

const CouponQuote _quote = CouponQuote(
  code: 'SAVE10',
  type: 'FIXED',
  currency: 'TRY',
  subtotal: '114.80',
  discount: '10.00',
  total: '104.80',
);

const Cart _emptyCart = Cart(
  id: 'cart_1',
  items: <CartItem>[],
  summary: CartSummary(itemCount: 0, subtotal: '0.00', currency: 'TRY'),
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

CheckoutSession _session() =>
    CheckoutSession(order: _order(), clientSecret: 'secret_1');

void main() {
  late MockCheckoutRepository repository;
  late MockPaymentSheetService sheet;
  late MockCartRepository cartRepository;

  setUp(() {
    repository = MockCheckoutRepository();
    sheet = MockPaymentSheetService();
    cartRepository = MockCartRepository();
    when(() => cartRepository.fetchCart()).thenAnswer((_) async => _emptyCart);
  });

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [
        checkoutRepositoryProvider.overrideWithValue(repository),
        paymentSheetServiceProvider.overrideWithValue(sheet),
        cartRepositoryProvider.overrideWithValue(cartRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts in review with no coupon', () {
    final ProviderContainer container = makeContainer();

    final CheckoutState state = container.read(checkoutControllerProvider);

    expect(state, isA<CheckoutReview>());
    expect((state as CheckoutReview).coupon, isNull);
  });

  test('applyCoupon stores the quoted discount', () async {
    when(() => repository.previewCoupon(any())).thenAnswer((_) async => _quote);

    final ProviderContainer container = makeContainer();
    await container
        .read(checkoutControllerProvider.notifier)
        .applyCoupon('save10');

    verify(() => repository.previewCoupon('save10')).called(1);
    final CheckoutState state = container.read(checkoutControllerProvider);
    expect((state as CheckoutReview).coupon?.code, 'SAVE10');
  });

  test('a rejected code rethrows and keeps the previous quote', () async {
    when(
      () => repository.previewCoupon('SAVE10'),
    ).thenAnswer((_) async => _quote);
    when(
      () => repository.previewCoupon('EXPIRED'),
    ).thenThrow(const ApiStatusException(400, 'Coupon has expired'));

    final ProviderContainer container = makeContainer();
    final CheckoutController controller = container.read(
      checkoutControllerProvider.notifier,
    );
    await controller.applyCoupon('SAVE10');

    await expectLater(
      controller.applyCoupon('EXPIRED'),
      throwsA(isA<ApiStatusException>()),
    );

    final CheckoutState state = container.read(checkoutControllerProvider);
    expect((state as CheckoutReview).coupon?.code, 'SAVE10');
  });

  test('removeCoupon drops the quote', () async {
    when(() => repository.previewCoupon(any())).thenAnswer((_) async => _quote);

    final ProviderContainer container = makeContainer();
    final CheckoutController controller = container.read(
      checkoutControllerProvider.notifier,
    );
    await controller.applyCoupon('SAVE10');

    controller.removeCoupon();

    final CheckoutState state = container.read(checkoutControllerProvider);
    expect((state as CheckoutReview).coupon, isNull);
  });

  test(
    'payNow places the order with the coupon, refreshes the cart, and '
    'succeeds when the sheet completes',
    () async {
      when(() => repository.previewCoupon(any())).thenAnswer(
        (_) async => _quote,
      );
      when(
        () => repository.placeOrder(
        couponCode: any(named: 'couponCode'),
        addressId: any(named: 'addressId'),
      ),
      ).thenAnswer((_) async => _session());
      when(
        () => sheet.present(clientSecret: any(named: 'clientSecret')),
      ).thenAnswer((_) async => PaymentSheetOutcome.completed);

      final ProviderContainer container = makeContainer();
      // Materialize the cart provider so the invalidation has one to refresh.
      await container.read(cartControllerProvider.future);
      final CheckoutController controller = container.read(
        checkoutControllerProvider.notifier,
      );
      await controller.applyCoupon('SAVE10');

      await controller.payNow();

      verify(
        () => repository.placeOrder(couponCode: 'SAVE10', addressId: null),
      ).called(1);
      verify(() => sheet.present(clientSecret: 'secret_1')).called(1);
      final CheckoutState state = container.read(checkoutControllerProvider);
      expect((state as CheckoutSuccess).order.id, 'ord_1');

      // The invalidated cart refetches when read again.
      container.read(cartControllerProvider);
      verify(() => cartRepository.fetchCart()).called(2);
    },
  );

  test('payNow forwards the chosen delivery address', () async {
    when(
      () => repository.placeOrder(
        couponCode: any(named: 'couponCode'),
        addressId: any(named: 'addressId'),
      ),
    ).thenAnswer((_) async => _session());
    when(
      () => sheet.present(clientSecret: any(named: 'clientSecret')),
    ).thenAnswer((_) async => PaymentSheetOutcome.completed);

    final ProviderContainer container = makeContainer();
    await container
        .read(checkoutControllerProvider.notifier)
        .payNow(addressId: 'a1');

    verify(
      () => repository.placeOrder(couponCode: null, addressId: 'a1'),
    ).called(1);
  });

  test('a cancelled sheet parks the flow as payment-pending', () async {
    when(
      () => repository.placeOrder(
        couponCode: any(named: 'couponCode'),
        addressId: any(named: 'addressId'),
      ),
    ).thenAnswer((_) async => _session());
    when(
      () => sheet.present(clientSecret: any(named: 'clientSecret')),
    ).thenAnswer((_) async => PaymentSheetOutcome.cancelled);

    final ProviderContainer container = makeContainer();
    await container.read(checkoutControllerProvider.notifier).payNow();

    final CheckoutState state = container.read(checkoutControllerProvider);
    expect(state, isA<CheckoutPaymentPending>());
    expect((state as CheckoutPaymentPending).clientSecret, 'secret_1');
  });

  test('retrying a pending payment reuses the intent, no new order', () async {
    when(
      () => repository.placeOrder(
        couponCode: any(named: 'couponCode'),
        addressId: any(named: 'addressId'),
      ),
    ).thenAnswer((_) async => _session());
    final List<PaymentSheetOutcome> outcomes = <PaymentSheetOutcome>[
      PaymentSheetOutcome.cancelled,
      PaymentSheetOutcome.completed,
    ];
    when(
      () => sheet.present(clientSecret: any(named: 'clientSecret')),
    ).thenAnswer((_) async => outcomes.removeAt(0));

    final ProviderContainer container = makeContainer();
    final CheckoutController controller = container.read(
      checkoutControllerProvider.notifier,
    );
    await controller.payNow();
    await controller.payNow();

    verify(
      () => repository.placeOrder(
        couponCode: any(named: 'couponCode'),
        addressId: any(named: 'addressId'),
      ),
    ).called(1);
    verify(() => sheet.present(clientSecret: 'secret_1')).called(2);
    expect(
      container.read(checkoutControllerProvider),
      isA<CheckoutSuccess>(),
    );
  });

  test('a failed payment rethrows and stays pending', () async {
    when(
      () => repository.placeOrder(
        couponCode: any(named: 'couponCode'),
        addressId: any(named: 'addressId'),
      ),
    ).thenAnswer((_) async => _session());
    when(
      () => sheet.present(clientSecret: any(named: 'clientSecret')),
    ).thenThrow(const PaymentException('Your card was declined.'));

    final ProviderContainer container = makeContainer();

    await expectLater(
      container.read(checkoutControllerProvider.notifier).payNow(),
      throwsA(
        isA<PaymentException>().having(
          (PaymentException e) => e.message,
          'message',
          'Your card was declined.',
        ),
      ),
    );

    expect(
      container.read(checkoutControllerProvider),
      isA<CheckoutPaymentPending>(),
    );
  });

  test('a rejected checkout keeps the review state, sheet untouched', () async {
    when(
      () => repository.placeOrder(
        couponCode: any(named: 'couponCode'),
        addressId: any(named: 'addressId'),
      ),
    ).thenThrow(const ApiStatusException(400, 'Cart is empty'));

    final ProviderContainer container = makeContainer();

    await expectLater(
      container.read(checkoutControllerProvider.notifier).payNow(),
      throwsA(isA<ApiStatusException>()),
    );

    expect(container.read(checkoutControllerProvider), isA<CheckoutReview>());
    verifyNever(() => sheet.present(clientSecret: any(named: 'clientSecret')));
  });

  test('payNow after success is a no-op', () async {
    when(
      () => repository.placeOrder(
        couponCode: any(named: 'couponCode'),
        addressId: any(named: 'addressId'),
      ),
    ).thenAnswer((_) async => _session());
    when(
      () => sheet.present(clientSecret: any(named: 'clientSecret')),
    ).thenAnswer((_) async => PaymentSheetOutcome.completed);

    final ProviderContainer container = makeContainer();
    final CheckoutController controller = container.read(
      checkoutControllerProvider.notifier,
    );
    await controller.payNow();

    await controller.payNow();

    verify(
      () => sheet.present(clientSecret: any(named: 'clientSecret')),
    ).called(1);
  });
}

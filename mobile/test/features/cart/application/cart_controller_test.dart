import 'dart:async';

import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/cart/application/cart_controller.dart';
import 'package:ecommerce_app/features/cart/data/cart_repository.dart';
import 'package:ecommerce_app/features/cart/domain/cart.dart';
import 'package:ecommerce_app/features/catalog/domain/product_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCartRepository extends Mock implements CartRepository {}

const ProductSummary _mug = ProductSummary(
  id: 'prd_1',
  slug: 'ceramic-mug',
  name: 'Ceramic Mug',
  price: '10.00',
  currency: 'TRY',
  stock: 10,
  isActive: true,
  imageUrl: null,
);

Cart _cart(int quantity) => Cart(
  id: 'cart_1',
  items: quantity == 0
      ? const <CartItem>[]
      : <CartItem>[
          CartItem(
            id: 'ci_1',
            productId: _mug.id,
            quantity: quantity,
            product: _mug,
          ),
        ],
  summary: CartSummary(
    itemCount: quantity,
    subtotal: (10.0 * quantity).toStringAsFixed(2),
    currency: 'TRY',
  ),
);

void main() {
  late MockCartRepository repository;

  setUp(() => repository = MockCartRepository());

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [cartRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads the cart on build and feeds the badge count', () async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _cart(2));

    final ProviderContainer container = makeContainer();
    final Cart cart = await container.read(cartControllerProvider.future);

    expect(cart.summary.itemCount, 2);
    expect(container.read(cartItemCountProvider), 2);
  });

  test('the badge is 0 while the cart is still loading', () {
    when(() => repository.fetchCart()).thenAnswer((_) async => _cart(2));

    final ProviderContainer container = makeContainer();

    expect(container.read(cartItemCountProvider), 0);
  });

  test('mutations replace the cart with the server response', () async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _cart(0));
    when(
      () => repository.addItem(
        productId: any(named: 'productId'),
        quantity: any(named: 'quantity'),
      ),
    ).thenAnswer((_) async => _cart(1));

    final ProviderContainer container = makeContainer();
    await container.read(cartControllerProvider.future);

    await container.read(cartControllerProvider.notifier).add('prd_1');

    verify(
      () => repository.addItem(productId: 'prd_1', quantity: 1),
    ).called(1);
    expect(container.read(cartControllerProvider).value!.summary.itemCount, 1);
  });

  test('a failed mutation keeps the last good cart and rethrows', () async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _cart(3));
    when(
      () => repository.updateItem(
        productId: any(named: 'productId'),
        quantity: any(named: 'quantity'),
      ),
    ).thenThrow(
      const ApiStatusException(
        400,
        'Only 3 unit(s) of this product are in stock',
      ),
    );

    final ProviderContainer container = makeContainer();
    await container.read(cartControllerProvider.future);

    await expectLater(
      container
          .read(cartControllerProvider.notifier)
          .updateQuantity('prd_1', 4),
      throwsA(isA<ApiStatusException>()),
    );

    final AsyncValue<Cart> state = container.read(cartControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.value!.summary.itemCount, 3);
  });

  test('an out-of-order response never wins over a newer one', () async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _cart(1));

    final Completer<Cart> slow = Completer<Cart>();
    when(
      () => repository.updateItem(
        productId: any(named: 'productId'),
        quantity: any(named: 'quantity'),
      ),
    ).thenAnswer((Invocation invocation) {
      final int quantity = invocation.namedArguments[#quantity] as int;
      // The older mutation (to 2) resolves *after* the newer one (to 3).
      return quantity == 2 ? slow.future : Future<Cart>.value(_cart(3));
    });

    final ProviderContainer container = makeContainer();
    final CartController controller = container.read(
      cartControllerProvider.notifier,
    );
    await container.read(cartControllerProvider.future);

    final Future<void> older = controller.updateQuantity('prd_1', 2);
    await controller.updateQuantity('prd_1', 3);
    slow.complete(_cart(2));
    await older;

    expect(container.read(cartControllerProvider).value!.summary.itemCount, 3);
  });

  test('remove and clear pass through to the repository', () async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _cart(1));
    when(() => repository.removeItem(any())).thenAnswer((_) async => _cart(0));
    when(() => repository.clear()).thenAnswer((_) async => _cart(0));

    final ProviderContainer container = makeContainer();
    final CartController controller = container.read(
      cartControllerProvider.notifier,
    );
    await container.read(cartControllerProvider.future);

    await controller.remove('prd_1');
    await controller.clear();

    verify(() => repository.removeItem('prd_1')).called(1);
    verify(() => repository.clear()).called(1);
    expect(container.read(cartControllerProvider).value!.isEmpty, isTrue);
  });
}

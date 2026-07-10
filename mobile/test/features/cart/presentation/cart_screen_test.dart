import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/cart/data/cart_repository.dart';
import 'package:ecommerce_app/features/cart/domain/cart.dart';
import 'package:ecommerce_app/features/cart/presentation/cart_screen.dart';
import 'package:ecommerce_app/features/catalog/domain/product_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCartRepository extends Mock implements CartRepository {}

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

void main() {
  late MockCartRepository repository;

  setUp(() => repository = MockCartRepository());

  Future<void> pumpCart(WidgetTester tester) async {
    // Portrait, like a real phone: the summary bar and both rows must fit.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry stays off in tests.
        retry: (int retryCount, Object error) => null,
        overrides: [cartRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: CartScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the lines and the server subtotal', (
    WidgetTester tester,
  ) async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _fullCart);

    await pumpCart(tester);

    expect(find.text('Ceramic Mug'), findsOneWidget);
    expect(find.text('Steel Bottle'), findsOneWidget);
    expect(find.text('₺99.80'), findsOneWidget); // 49.90 × 2 line total
    expect(find.text('₺114.80'), findsOneWidget); // server subtotal
    expect(find.text('3 items'), findsOneWidget);
    // Checkout is a stub until the next slice.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Checkout'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('the plus stepper sets the next absolute quantity', (
    WidgetTester tester,
  ) async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _fullCart);
    when(
      () => repository.updateItem(
        productId: any(named: 'productId'),
        quantity: any(named: 'quantity'),
      ),
    ).thenAnswer((_) async => _fullCart);

    await pumpCart(tester);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    verify(
      () => repository.updateItem(productId: 'prd_1', quantity: 3),
    ).called(1);
  });

  testWidgets('minus on a single unit removes the line instead', (
    WidgetTester tester,
  ) async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _fullCart);
    when(
      () => repository.removeItem(any()),
    ).thenAnswer((_) async => _emptyCart);

    await pumpCart(tester);

    // Only the bottle (quantity 1) renders its minus as a trash can.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    verify(() => repository.removeItem('prd_2')).called(1);
  });

  testWidgets('clearing asks first, then empties the cart', (
    WidgetTester tester,
  ) async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _fullCart);
    when(() => repository.clear()).thenAnswer((_) async => _emptyCart);

    await pumpCart(tester);

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Clear the cart?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    verify(() => repository.clear()).called(1);
    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('cancelling the dialog clears nothing', (
    WidgetTester tester,
  ) async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _fullCart);

    await pumpCart(tester);

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => repository.clear());
    expect(find.text('Ceramic Mug'), findsOneWidget);
  });

  testWidgets('an empty cart points back to the catalog', (
    WidgetTester tester,
  ) async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _emptyCart);

    await pumpCart(tester);

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Browse products'), findsOneWidget);
  });

  testWidgets('a rejected quantity change shows the server message', (
    WidgetTester tester,
  ) async {
    when(() => repository.fetchCart()).thenAnswer((_) async => _fullCart);
    when(
      () => repository.updateItem(
        productId: any(named: 'productId'),
        quantity: any(named: 'quantity'),
      ),
    ).thenThrow(
      const ApiStatusException(
        400,
        'Only 2 unit(s) of this product are in stock',
      ),
    );

    await pumpCart(tester);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(
      find.text('Only 2 unit(s) of this product are in stock'),
      findsOneWidget,
    );
    // The cart itself is untouched.
    expect(find.text('₺114.80'), findsOneWidget);
  });
}

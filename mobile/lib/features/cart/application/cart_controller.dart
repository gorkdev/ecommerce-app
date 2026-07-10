import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cart_repository.dart';
import '../domain/cart.dart';

/// Owns the cart. The server recomputes and returns the whole cart on every
/// mutation, so this controller only ever *replaces* its state — no local
/// cart math, no drift.
///
/// Mutations do not flip the state to loading: the current cart stays on
/// screen while the round-trip runs. Failures propagate as [ApiException]
/// for the screen to show (e.g. the stock-limit message), leaving the last
/// good cart in place.
final class CartController extends AsyncNotifier<Cart> {
  int _operation = 0;

  @override
  Future<Cart> build() {
    _operation++;
    return ref.read(cartRepositoryProvider).fetchCart();
  }

  Future<void> add(String productId, {int quantity = 1}) => _mutate(
    (CartRepository repository) =>
        repository.addItem(productId: productId, quantity: quantity),
  );

  Future<void> updateQuantity(String productId, int quantity) => _mutate(
    (CartRepository repository) =>
        repository.updateItem(productId: productId, quantity: quantity),
  );

  Future<void> remove(String productId) =>
      _mutate((CartRepository repository) => repository.removeItem(productId));

  Future<void> clear() =>
      _mutate((CartRepository repository) => repository.clear());

  Future<void> reload() async {
    final int operation = ++_operation;
    state = const AsyncLoading<Cart>();
    final AsyncValue<Cart> next = await AsyncValue.guard<Cart>(
      () => ref.read(cartRepositoryProvider).fetchCart(),
    );
    if (operation != _operation || !ref.mounted) return;
    state = next;
  }

  /// Rapid taps (quantity steppers) can make responses arrive out of order;
  /// only the newest mutation's cart snapshot may win.
  Future<void> _mutate(Future<Cart> Function(CartRepository) run) async {
    final int operation = ++_operation;
    final Cart cart = await run(ref.read(cartRepositoryProvider));
    if (operation != _operation || !ref.mounted) return;
    state = AsyncData<Cart>(cart);
  }
}

final AsyncNotifierProvider<CartController, Cart> cartControllerProvider =
    AsyncNotifierProvider<CartController, Cart>(CartController.new);

/// Item count for the cart badge; 0 while the cart is still loading.
final Provider<int> cartItemCountProvider = Provider<int>(
  (ref) => ref.watch(cartControllerProvider).value?.summary.itemCount ?? 0,
);

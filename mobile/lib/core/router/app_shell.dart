import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/application/cart_controller.dart';
import '../l10n/l10n.dart';

/// Bottom-nav scaffold hosting the five tab branches. Tab state is preserved
/// by the indexed stack; full-screen flows (product detail, checkout, …)
/// push over this on the root navigator.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int cartCount = ref.watch(cartItemCountProvider);
    final l10n = context.l10n;

    Widget cartIcon(IconData icon) => Badge(
      isLabelVisible: cartCount > 0,
      label: Text('$cartCount'),
      child: Icon(icon),
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) => navigationShell.goBranch(
          index,
          // Re-tapping the active tab pops it back to its root.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: <Widget>[
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: l10n.navDiscover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline),
            selectedIcon: const Icon(Icons.favorite),
            label: l10n.navFavorites,
          ),
          NavigationDestination(
            icon: cartIcon(Icons.shopping_bag_outlined),
            selectedIcon: cartIcon(Icons.shopping_bag),
            label: l10n.navCart,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.navOrders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}

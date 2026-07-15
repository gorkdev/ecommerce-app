import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/formatting/price_formatter.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/remote_thumbnail.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../catalog/presentation/catalog_screen.dart';
import '../../checkout/presentation/checkout_screen.dart';
import '../application/cart_controller.dart';
import '../domain/cart.dart';

/// The cart: line items with quantity steppers and the server-computed
/// subtotal, leading into the checkout flow.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  static const String path = '/cart';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Cart> cartState = ref.watch(cartControllerProvider);
    final Cart? cart = cartState.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cart),
        actions: <Widget>[
          if (cart != null && !cart.isEmpty)
            IconButton(
              tooltip: context.l10n.clearCart,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: _buildBody(context, ref, cartState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Cart> cartState,
  ) {
    final Cart? cart = cartState.value;
    if (cart == null) {
      if (cartState.hasError) {
        return ErrorView(
          error: cartState.error,
          onRetry: () => ref.read(cartControllerProvider.notifier).reload(),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (cart.isEmpty) {
      return EmptyView(
        icon: Icons.shopping_cart_outlined,
        title: context.l10n.cartEmptyTitle,
        subtitle: context.l10n.cartEmptyHint,
        action: FilledButton.tonal(
          onPressed: () => context.go(CatalogScreen.path),
          child: Text(context.l10n.browseProducts),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.separated(
            padding: AppTokens.screenPadding,
            itemCount: cart.items.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTokens.space3),
            itemBuilder: (_, int index) => _CartItemTile(cart.items[index]),
          ),
        ),
        _CartSummaryBar(cart.summary),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.clearCartTitle),
        content: Text(l10n.clearCartBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(cartControllerProvider.notifier).clear();
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
    }
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile(this.item);

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final String? warning = !item.product.isActive
        ? context.l10n.noLongerAvailable
        : item.quantity > item.product.stock
        ? context.l10n.onlyNLeftInStock(item.product.stock)
        : null;

    return Dismissible(
      key: ValueKey<String>(item.productId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTokens.space5),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      // The row may only disappear once the server confirmed the removal —
      // dismissing a widget that then stays in the tree is an error.
      confirmDismiss: (_) => _remove(context, ref),
      child: SoftCard(
        padding: const EdgeInsets.all(AppTokens.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            RemoteThumbnail(url: item.product.imageUrl, size: 72),
            const SizedBox(width: AppTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PriceFormatter.format(
                      item.product.price,
                      item.product.currency,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (warning != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      warning,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppTokens.space2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  PriceFormatter.format(item.lineTotal, item.product.currency),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space1),
                _QuantityStepper(item),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(cartControllerProvider.notifier).remove(item.productId);
      return true;
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
      }
      return false;
    }
  }
}

class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper(this.item);

  static const int _maxQuantity = 99; // Mirrors the server DTO's @Max(99).

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bool canIncrease =
        item.quantity < _maxQuantity && item.quantity < item.product.stock;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            tooltip: item.quantity == 1
                ? context.l10n.remove
                : context.l10n.decreaseQuantity,
            icon: Icon(
              item.quantity == 1 ? Icons.delete_outline : Icons.remove,
            ),
            onPressed: () => _run(
              context,
              ref,
              (CartController cart) => item.quantity == 1
                  ? cart.remove(item.productId)
                  : cart.updateQuantity(item.productId, item.quantity - 1),
            ),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            tooltip: context.l10n.increaseQuantity,
            icon: const Icon(Icons.add),
            onPressed: !canIncrease
                ? null
                : () => _run(
                    context,
                    ref,
                    (CartController cart) =>
                        cart.updateQuantity(item.productId, item.quantity + 1),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(CartController) action,
  ) async {
    try {
      await action(ref.read(cartControllerProvider.notifier));
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
    }
  }
}

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar(this.summary);

  final CartSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space5,
            AppTokens.space3,
            AppTokens.space5,
            AppTokens.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.subtotal,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          context.l10n.nItems(summary.itemCount),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    PriceFormatter.format(summary.subtotal, summary.currency),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space3),
              FilledButton(
                onPressed: () => context.push(CheckoutScreen.path),
                child: Text(context.l10n.checkout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

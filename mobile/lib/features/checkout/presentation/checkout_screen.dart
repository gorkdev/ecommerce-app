import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/formatting/price_formatter.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../cart/application/cart_controller.dart';
import '../../cart/domain/cart.dart';
import '../../catalog/presentation/catalog_screen.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/orders_screen.dart';
import '../application/checkout_controller.dart';
import '../data/payment_sheet_service.dart';
import '../domain/coupon_quote.dart';

/// The checkout flow: review the cart and quote a coupon, place the order,
/// and confirm the payment through Stripe's payment sheet. The body renders
/// whichever phase the [CheckoutController] state machine is in.
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  static const String path = '/checkout';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CheckoutState state = ref.watch(checkoutControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: switch (state) {
        CheckoutSuccess(:final Order order) => _SuccessView(order),
        CheckoutPaymentPending(:final Order order) => _PaymentPendingView(order),
        final CheckoutReview review => _ReviewView(review),
      },
    );
  }
}

/// Phase 1: the cart summary, the coupon field, and the pay button.
class _ReviewView extends ConsumerStatefulWidget {
  const _ReviewView(this.review);

  final CheckoutReview review;

  @override
  ConsumerState<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<_ReviewView> {
  final TextEditingController _couponController = TextEditingController();
  bool _applyingCoupon = false;
  bool _paying = false;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Cart> cartState = ref.watch(cartControllerProvider);
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
        title: 'Your cart is empty',
        subtitle: 'Add something before checking out.',
        action: FilledButton.tonal(
          onPressed: () => context.go(CatalogScreen.path),
          child: const Text('Browse products'),
        ),
      );
    }

    final CouponQuote? coupon = widget.review.coupon;
    // Totals are server-computed: the cart summary before a coupon, the
    // quote afterwards. The client never does its own money math here.
    final String total = coupon?.total ?? cart.summary.subtotal;
    final String currency = coupon?.currency ?? cart.summary.currency;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              for (final CartItem item in cart.items) _OrderLine(item),
              const SizedBox(height: 8),
              _CouponSection(
                coupon: coupon,
                controller: _couponController,
                busy: _applyingCoupon,
                onApply: _applyCoupon,
                onRemove: () =>
                    ref.read(checkoutControllerProvider.notifier).removeCoupon(),
              ),
              const Divider(height: 32),
              _TotalRow(
                label: 'Subtotal',
                amount: PriceFormatter.format(
                  coupon?.subtotal ?? cart.summary.subtotal,
                  currency,
                ),
              ),
              if (coupon != null)
                _TotalRow(
                  label: 'Discount (${coupon.code})',
                  amount:
                      '−${PriceFormatter.format(coupon.discount, currency)}',
                ),
              const SizedBox(height: 4),
              _TotalRow(
                label: 'Total',
                amount: PriceFormatter.format(total, currency),
                emphasized: true,
              ),
            ],
          ),
        ),
        _BottomBar(
          child: FilledButton(
            onPressed: _paying ? null : _pay,
            child: _paying
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Pay ${PriceFormatter.format(total, currency)}'),
          ),
        ),
      ],
    );
  }

  Future<void> _applyCoupon() async {
    final String code = _couponController.text.trim();
    if (code.isEmpty) return;
    setState(() => _applyingCoupon = true);
    try {
      await ref.read(checkoutControllerProvider.notifier).applyCoupon(code);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _applyingCoupon = false);
    }
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      await ref.read(checkoutControllerProvider.notifier).payNow();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } on PaymentException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _OrderLine extends StatelessWidget {
  const _OrderLine(this.item);

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Text(
            '${item.quantity}×',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            PriceFormatter.format(item.lineTotal, item.product.currency),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CouponSection extends StatelessWidget {
  const _CouponSection({
    required this.coupon,
    required this.controller,
    required this.busy,
    required this.onApply,
    required this.onRemove,
  });

  final CouponQuote? coupon;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final CouponQuote? applied = coupon;

    if (applied != null) {
      return Row(
        children: <Widget>[
          Icon(Icons.local_offer_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(applied.code, style: theme.textTheme.titleSmall),
          ),
          IconButton(
            tooltip: 'Remove coupon',
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Coupon code',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => onApply(),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: busy ? null : onApply,
          child: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply'),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final String amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextStyle? style = emphasized
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(amount, style: style),
        ],
      ),
    );
  }
}

/// Phase 2: the order exists but its payment does not — the sheet was
/// cancelled or the card was declined. Stock stays reserved on the PENDING
/// order, so the retry confirms the very same PaymentIntent.
class _PaymentPendingView extends ConsumerStatefulWidget {
  const _PaymentPendingView(this.order);

  final Order order;

  @override
  ConsumerState<_PaymentPendingView> createState() =>
      _PaymentPendingViewState();
}

class _PaymentPendingViewState extends ConsumerState<_PaymentPendingView> {
  bool _paying = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Order order = widget.order;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.hourglass_top,
              size: 56,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment not completed',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Order #${order.reference} is placed and waiting for its '
              'payment of ${PriceFormatter.format(order.total, order.currency)}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _paying ? null : _retry,
              child: _paying
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Pay now'),
            ),
            TextButton(
              onPressed: () => context.go(CatalogScreen.path),
              child: const Text('Back to the catalog'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retry() async {
    setState(() => _paying = true);
    try {
      await ref.read(checkoutControllerProvider.notifier).payNow();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } on PaymentException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Phase 3: the sheet confirmed the payment. The PAID flip happens through
/// the Stripe webhook; order tracking arrives with the orders slice.
class _SuccessView extends StatelessWidget {
  const _SuccessView(this.order);

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment received',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Order #${order.reference} — '
              '${PriceFormatter.format(order.total, order.currency)}. '
              'We are preparing it now.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(CatalogScreen.path),
              child: const Text('Continue shopping'),
            ),
            TextButton(
              // Replace the finished checkout so back lands on the cart.
              onPressed: () => context.pushReplacement(OrdersScreen.path),
              child: const Text('View my orders'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[child],
          ),
        ),
      ),
    );
  }
}

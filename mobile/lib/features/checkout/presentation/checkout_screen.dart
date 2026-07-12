import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/formatting/price_formatter.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../addresses/application/addresses_controller.dart';
import '../../addresses/domain/address.dart';
import '../../addresses/presentation/addresses_screen.dart';
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
      appBar: AppBar(title: Text(context.l10n.checkout)),
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

  /// The user's explicit pick; null means "use the default address".
  String? _selectedAddressId;

  /// Resolves the pick against the live list — a deleted selection falls
  /// back to the default, and no addresses means none at all.
  Address? _selectedAddress(List<Address> addresses) {
    Address? fallback;
    for (final Address address in addresses) {
      if (address.id == _selectedAddressId) return address;
      if (address.isDefault) fallback = address;
    }
    return fallback;
  }

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
        title: context.l10n.cartEmptyTitle,
        subtitle: context.l10n.checkoutEmptyHint,
        action: FilledButton.tonal(
          onPressed: () => context.go(CatalogScreen.path),
          child: Text(context.l10n.browseProducts),
        ),
      );
    }

    final CouponQuote? coupon = widget.review.coupon;
    // Totals are server-computed: the cart summary before a coupon, the
    // quote afterwards. The client never does its own money math here.
    final String total = coupon?.total ?? cart.summary.subtotal;
    final String currency = coupon?.currency ?? cart.summary.currency;

    final List<Address> addresses =
        ref.watch(addressesControllerProvider).value ?? const <Address>[];
    final Address? deliverTo = _selectedAddress(addresses);

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _DeliverToCard(
                address: deliverTo,
                onChange: addresses.isEmpty
                    ? () => context.push(AddressesScreen.path)
                    : () => _pickAddress(addresses, deliverTo),
              ),
              const Divider(height: 32),
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
                label: context.l10n.subtotal,
                amount: PriceFormatter.format(
                  coupon?.subtotal ?? cart.summary.subtotal,
                  currency,
                ),
              ),
              if (coupon != null)
                _TotalRow(
                  label: context.l10n.discountWithCode(coupon.code),
                  amount:
                      '−${PriceFormatter.format(coupon.discount, currency)}',
                ),
              const SizedBox(height: 4),
              _TotalRow(
                label: context.l10n.total,
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
                : Text(
                    context.l10n.payAmount(
                      PriceFormatter.format(total, currency),
                    ),
                  ),
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
      if (mounted) _showMessage(context.l10n.errorText(error));
    } finally {
      if (mounted) setState(() => _applyingCoupon = false);
    }
  }

  Future<void> _pickAddress(List<Address> addresses, Address? current) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final Address address in addresses)
              ListTile(
                leading: Icon(
                  address.id == current?.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(address.fullName),
                subtitle: Text('${address.line1} · ${address.locality}'),
                onTap: () => Navigator.of(sheetContext).pop(address.id),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.push(AddressesScreen.path);
              },
              child: Text(context.l10n.manageAddresses),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedAddressId = picked);
    }
  }

  Future<void> _pay() async {
    final List<Address> addresses =
        ref.read(addressesControllerProvider).value ?? const <Address>[];
    final Address? deliverTo = _selectedAddress(addresses);

    setState(() => _paying = true);
    try {
      await ref
          .read(checkoutControllerProvider.notifier)
          .payNow(addressId: deliverTo?.id);
    } on ApiException catch (error) {
      if (mounted) _showMessage(context.l10n.errorText(error));
    } on PaymentException catch (error) {
      // Stripe already localizes its own failure messages.
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

/// Where the order ships. Optional server-side, so checkout stays usable
/// with an empty address book — the card then invites adding one.
class _DeliverToCard extends StatelessWidget {
  const _DeliverToCard({required this.address, required this.onChange});

  final Address? address;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Address? deliverTo = address;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.location_on_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: deliverTo == null
              ? Text(
                  context.l10n.noDeliveryAddress,
                  style: theme.textTheme.bodyMedium,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      deliverTo.fullName,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      '${deliverTo.line1} · ${deliverTo.locality}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
        TextButton(
          onPressed: onChange,
          child: Text(
            deliverTo == null ? context.l10n.add : context.l10n.change,
          ),
        ),
      ],
    );
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
            tooltip: context.l10n.removeCoupon,
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
            decoration: InputDecoration(
              labelText: context.l10n.couponCode,
              isDense: true,
              border: const OutlineInputBorder(),
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
              : Text(context.l10n.apply),
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
              context.l10n.paymentNotCompleted,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.paymentPendingBody(
                order.reference,
                PriceFormatter.format(order.total, order.currency),
              ),
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
                  : Text(context.l10n.payNow),
            ),
            TextButton(
              onPressed: () => context.go(CatalogScreen.path),
              child: Text(context.l10n.backToCatalog),
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
      if (mounted) _showMessage(context.l10n.errorText(error));
    } on PaymentException catch (error) {
      // Stripe already localizes its own failure messages.
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
              context.l10n.paymentReceived,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.paymentSuccessBody(
                order.reference,
                PriceFormatter.format(order.total, order.currency),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(CatalogScreen.path),
              child: Text(context.l10n.continueShopping),
            ),
            TextButton(
              // Replace the finished checkout so back lands on the cart.
              onPressed: () => context.pushReplacement(OrdersScreen.path),
              child: Text(context.l10n.viewMyOrders),
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

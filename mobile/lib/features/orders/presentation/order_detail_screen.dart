import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/formatting/date_formatter.dart';
import '../../../shared/formatting/price_formatter.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/remote_thumbnail.dart';
import '../../catalog/presentation/product_detail_screen.dart';
import '../application/orders_providers.dart';
import '../domain/order.dart';
import 'widgets/order_status_chip.dart';

/// One order: fulfilment progress, the snapshot-priced lines, and the totals
/// exactly as they were charged.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  static const String path = '/orders/:id';

  static String location(String id) => '/orders/$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Order> orderState = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: _buildBody(context, ref, orderState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Order> orderState,
  ) {
    final Order? order = orderState.value;
    if (order == null) {
      if (orderState.hasError) {
        final Object? error = orderState.error;
        // A 404 is final — retrying will not bring the order back.
        if (error is ApiStatusException && error.isNotFound) {
          return ErrorView(error: error, icon: Icons.receipt_long_outlined);
        }
        return ErrorView(
          error: error,
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(orderDetailProvider(orderId).future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Order #${order.reference}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              OrderStatusChip(order.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Placed ${DateFormatter.dateTime(order.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _StatusTimeline(order.status),
          const Divider(height: 32),
          Text('Items', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final OrderItem item in order.items)
            _OrderItemTile(item, currency: order.currency),
          const Divider(height: 32),
          _TotalRow(
            label: 'Subtotal',
            amount: PriceFormatter.format(order.subtotal, order.currency),
          ),
          if (order.hasDiscount)
            _TotalRow(
              label: order.coupon == null
                  ? 'Discount'
                  : 'Discount (${order.coupon!.code})',
              amount:
                  '−${PriceFormatter.format(order.discountTotal, order.currency)}',
            ),
          const SizedBox(height: 4),
          _TotalRow(
            label: 'Total',
            amount: PriceFormatter.format(order.total, order.currency),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

/// The fulfilment ladder — or, for a cancelled/refunded order, a banner in
/// its place: those states are terminal, not steps on the way to delivery.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline(this.status);

  final OrderStatus status;

  static const List<(OrderStatus, String)> _steps = <(OrderStatus, String)>[
    (OrderStatus.pending, 'Order placed'),
    (OrderStatus.paid, 'Payment confirmed'),
    (OrderStatus.preparing, 'Preparing'),
    (OrderStatus.shipped, 'Shipped'),
    (OrderStatus.delivered, 'Delivered'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (status == OrderStatus.cancelled || status == OrderStatus.refunded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status == OrderStatus.cancelled
              ? 'This order was cancelled.'
              : 'This order was refunded.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      );
    }

    final int reached = _steps.indexWhere(
      ((OrderStatus, String) step) => step.$1 == status,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final (int index, (OrderStatus, String) step)
            in _steps.indexed) ...<Widget>[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Container(
                width: 2,
                height: 14,
                color: index <= reached
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
          Row(
            children: <Widget>[
              Icon(
                index <= reached
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 24,
                color: index <= reached
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
              const SizedBox(width: 12),
              Text(
                step.$2,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: index <= reached
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile(this.item, {required this.currency});

  final OrderItem item;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? slug = item.productSlug;

    return InkWell(
      // Best effort: the product may have been removed from the catalog.
      onTap: slug == null
          ? null
          : () => context.push(ProductDetailScreen.location(slug)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            RemoteThumbnail(url: item.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantity} × '
                    '${PriceFormatter.format(item.unitPrice, currency)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              PriceFormatter.format(item.lineTotal, currency),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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

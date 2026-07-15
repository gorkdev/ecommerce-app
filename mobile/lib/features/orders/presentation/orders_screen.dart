import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/formatting/date_formatter.dart';
import '../../../shared/formatting/price_formatter.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../catalog/presentation/catalog_screen.dart';
import '../application/orders_providers.dart';
import '../domain/order.dart';
import 'order_detail_screen.dart';
import 'widgets/order_status_chip.dart';

/// The user's order history, newest first. Pull to refresh picks up status
/// changes made server-side (payment webhooks, admin fulfilment).
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  static const String path = '/orders';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Order>> ordersState = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.myOrders)),
      body: _buildBody(context, ref, ordersState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Order>> ordersState,
  ) {
    final List<Order>? orders = ordersState.value;
    if (orders == null) {
      if (ordersState.hasError) {
        return ErrorView(
          error: ordersState.error,
          onRetry: () => ref.invalidate(ordersProvider),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return EmptyView(
        icon: Icons.receipt_long_outlined,
        title: context.l10n.noOrdersYet,
        subtitle: context.l10n.noOrdersHint,
        action: FilledButton.tonal(
          onPressed: () => context.go(CatalogScreen.path),
          child: Text(context.l10n.browseProducts),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(ordersProvider.future),
      child: ListView.separated(
        padding: AppTokens.screenPadding,
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space3),
        itemBuilder: (_, int index) => _OrderCard(orders[index]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.order);

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SoftCard(
      onTap: () => context.push(OrderDetailScreen.location(order.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.orderRef(order.reference),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatter.date(order.createdAt, context.l10n.localeName),
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  context.l10n.nItems(order.itemCount),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                PriceFormatter.format(order.total, order.currency),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space1),
              OrderStatusChip(order.status),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/order.dart';
import 'order_status_label.dart';

/// A compact pastel pill for an order's lifecycle state — every status gets
/// its own hue so a list of orders reads at a glance.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key});

  final OrderStatus status;

  /// The one place a status maps to its pastel pair.
  static PastelPair pairFor(AppTokens tokens, OrderStatus status) =>
      switch (status) {
        OrderStatus.pending => tokens.amber,
        OrderStatus.paid => tokens.periwinkle,
        OrderStatus.preparing => tokens.violet,
        OrderStatus.shipped => tokens.cyan,
        OrderStatus.delivered => tokens.mint,
        OrderStatus.cancelled => tokens.neutral,
        OrderStatus.refunded => tokens.rose,
      };

  @override
  Widget build(BuildContext context) {
    final PastelPair pair = pairFor(AppTokens.of(context), status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: pair.container,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label(context.l10n),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: pair.onContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

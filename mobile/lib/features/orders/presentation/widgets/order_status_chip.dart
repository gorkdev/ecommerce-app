import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../domain/order.dart';
import 'order_status_label.dart';

/// A compact, color-coded label for an order's lifecycle state.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      OrderStatus.pending => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      OrderStatus.paid ||
      OrderStatus.preparing ||
      OrderStatus.shipped => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      OrderStatus.delivered => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      OrderStatus.cancelled ||
      OrderStatus.refunded => (colors.errorContainer, colors.onErrorContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label(context.l10n),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

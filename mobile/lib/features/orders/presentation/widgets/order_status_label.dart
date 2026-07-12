import '../../../../core/l10n/l10n.dart';
import '../../domain/order.dart';

/// Localized display names for [OrderStatus] — presentation-side so the
/// domain enum stays a pure wire mapping.
extension OrderStatusLabel on OrderStatus {
  String label(AppLocalizations l10n) => switch (this) {
    OrderStatus.pending => l10n.statusPending,
    OrderStatus.paid => l10n.statusPaid,
    OrderStatus.preparing => l10n.statusPreparing,
    OrderStatus.shipped => l10n.statusShipped,
    OrderStatus.delivered => l10n.statusDelivered,
    OrderStatus.cancelled => l10n.statusCancelled,
    OrderStatus.refunded => l10n.statusRefunded,
  };
}

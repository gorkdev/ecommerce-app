import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/core/theme/app_tokens.dart';
import 'package:ecommerce_app/features/orders/domain/order.dart';
import 'package:ecommerce_app/features/orders/presentation/widgets/order_status_chip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every status maps to a distinct pastel pair', () {
    final AppTokens tokens = AppTheme.light.extension<AppTokens>()!;
    final Map<OrderStatus, PastelPair> pairs = <OrderStatus, PastelPair>{
      for (final OrderStatus status in OrderStatus.values)
        status: OrderStatusChip.pairFor(tokens, status),
    };

    expect(pairs[OrderStatus.pending], same(tokens.amber));
    expect(pairs[OrderStatus.paid], same(tokens.periwinkle));
    expect(pairs[OrderStatus.preparing], same(tokens.violet));
    expect(pairs[OrderStatus.shipped], same(tokens.cyan));
    expect(pairs[OrderStatus.delivered], same(tokens.mint));
    expect(pairs[OrderStatus.cancelled], same(tokens.neutral));
    expect(pairs[OrderStatus.refunded], same(tokens.rose));

    // No two statuses share a container color.
    final Set<Object> containers = pairs.values
        .map((PastelPair p) => p.container)
        .toSet();
    expect(containers.length, OrderStatus.values.length);
  });
}

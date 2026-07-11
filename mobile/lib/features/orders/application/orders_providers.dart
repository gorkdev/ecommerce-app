import 'package:flutter_riverpod/flutter_riverpod.dart';
// The family types live in the `misc` library, not the main export.
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../data/orders_repository.dart';
import '../domain/order.dart';

/// The user's order history. Auto-disposed: statuses move server-side (the
/// webhook flips PENDING to PAID, admins advance fulfilment), so every visit
/// refetches instead of trusting a stale cache.
final FutureProvider<List<Order>> ordersProvider =
    FutureProvider.autoDispose<List<Order>>(
      (ref) => ref.watch(ordersRepositoryProvider).fetchOrders(),
    );

/// One order by id — same freshness rationale as [ordersProvider].
final FutureProviderFamily<Order, String> orderDetailProvider =
    FutureProvider.autoDispose.family<Order, String>(
      (ref, id) => ref.watch(ordersRepositoryProvider).fetchOrder(id),
    );

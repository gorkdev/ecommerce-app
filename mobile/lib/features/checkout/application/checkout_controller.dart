import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/application/cart_controller.dart';
import '../../orders/domain/order.dart';
import '../data/checkout_repository.dart';
import '../data/payment_sheet_service.dart';
import '../domain/checkout_session.dart';
import '../domain/coupon_quote.dart';

/// Where the checkout flow stands. A plain state machine: the screen renders
/// whichever phase is active, the controller owns every transition.
sealed class CheckoutState {
  const CheckoutState();
}

/// Reviewing the cart; a coupon may be quoted. The order does not exist yet.
final class CheckoutReview extends CheckoutState {
  const CheckoutReview({this.coupon});

  final CouponQuote? coupon;
}

/// The PENDING order exists server-side (stock reserved, cart emptied) but
/// the payment has not gone through — the sheet was cancelled or failed.
/// Retrying confirms the same PaymentIntent with the same client secret.
final class CheckoutPaymentPending extends CheckoutState {
  const CheckoutPaymentPending({
    required this.order,
    required this.clientSecret,
  });

  final Order order;
  final String clientSecret;
}

/// The sheet reported the payment as completed. The order itself flips to
/// PAID via the Stripe webhook, not by anything the app does.
final class CheckoutSuccess extends CheckoutState {
  const CheckoutSuccess(this.order);

  final Order order;
}

final class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutReview();

  /// Quotes [code] against the current cart. Validation failures (unknown
  /// code, below minimum, expired) rethrow as `ApiException` carrying the
  /// server's message; whatever quote was applied before stays in place.
  Future<void> applyCoupon(String code) async {
    final CouponQuote quote = await ref
        .read(checkoutRepositoryProvider)
        .previewCoupon(code);
    if (!ref.mounted || state is! CheckoutReview) return;
    state = CheckoutReview(coupon: quote);
  }

  void removeCoupon() {
    if (state is! CheckoutReview) return;
    state = const CheckoutReview();
  }

  /// Places the order (first call) or retries a pending payment, then
  /// presents the payment sheet. `ApiException` / [PaymentException]
  /// propagate to the caller for snackbars; the state always reflects how
  /// far the flow actually got.
  Future<void> payNow() async {
    final CheckoutState current = state;
    final Order order;
    final String clientSecret;
    switch (current) {
      case CheckoutReview(:final CouponQuote? coupon):
        final CheckoutSession session = await ref
            .read(checkoutRepositoryProvider)
            .placeOrder(couponCode: coupon?.code);
        // Checkout emptied the cart server-side; drop the cached copy so the
        // badge and the cart screen refetch instead of showing stale lines.
        ref.invalidate(cartControllerProvider);
        if (!ref.mounted) return;
        order = session.order;
        clientSecret = session.clientSecret;
        state = CheckoutPaymentPending(
          order: order,
          clientSecret: clientSecret,
        );
      case CheckoutPaymentPending():
        order = current.order;
        clientSecret = current.clientSecret;
      case CheckoutSuccess():
        return;
    }

    final PaymentSheetOutcome outcome = await ref
        .read(paymentSheetServiceProvider)
        .present(clientSecret: clientSecret);
    if (!ref.mounted) return;
    if (outcome == PaymentSheetOutcome.completed) {
      state = CheckoutSuccess(order);
    }
    // Cancelled: stay in CheckoutPaymentPending so the user can retry.
  }
}

final checkoutControllerProvider =
    NotifierProvider.autoDispose<CheckoutController, CheckoutState>(
      CheckoutController.new,
    );

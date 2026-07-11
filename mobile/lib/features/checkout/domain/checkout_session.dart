import '../../orders/domain/order.dart';

/// What `POST /orders/checkout` hands back: the freshly created PENDING order
/// and the Stripe PaymentIntent client secret the payment sheet confirms.
final class CheckoutSession {
  const CheckoutSession({required this.order, required this.clientSecret});

  factory CheckoutSession.fromJson(Map<String, dynamic> json) =>
      CheckoutSession(
        order: Order.fromJson(json['order'] as Map<String, dynamic>),
        clientSecret: json['clientSecret'] as String,
      );

  final Order order;
  final String clientSecret;
}

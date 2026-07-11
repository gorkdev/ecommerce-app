/// A dry-run quote from `POST /coupons/apply`: what a code would knock off the
/// caller's current cart. Nothing is committed — the real redemption happens
/// atomically at checkout, where the server re-validates the code.
final class CouponQuote {
  const CouponQuote({
    required this.code,
    required this.type,
    required this.currency,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  factory CouponQuote.fromJson(Map<String, dynamic> json) => CouponQuote(
    code: json['code'] as String,
    type: json['type'] as String,
    currency: json['currency'] as String,
    subtotal: json['subtotal'] as String,
    discount: json['discount'] as String,
    total: json['total'] as String,
  );

  final String code;

  /// `PERCENTAGE` or `FIXED` — display only, the server did the math.
  final String type;
  final String currency;
  final String subtotal;
  final String discount;
  final String total;
}

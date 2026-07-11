import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../core/config/app_config.dart';

/// How a payment-sheet round ended. A cancelled sheet is a normal outcome
/// (the user backed out), not an error — the PaymentIntent stays confirmable.
enum PaymentSheetOutcome { completed, cancelled }

/// The payment itself failed: declined card, timeout, missing configuration.
final class PaymentException implements Exception {
  const PaymentException(this.message);

  /// Human-readable, safe to show in a snackbar.
  final String message;

  @override
  String toString() => 'PaymentException: $message';
}

/// The single seam that touches the Stripe SDK — the mobile mirror of the
/// API's `PaymentService`. Everything above talks to this class, which keeps
/// native payment-sheet calls (impossible under `flutter test`) mockable.
///
/// Left open (not `final`) so tests can stand in a mock for it.
class PaymentSheetService {
  const PaymentSheetService();

  /// Initializes and presents Stripe's payment sheet for [clientSecret].
  ///
  /// Throws [PaymentException] when the payment fails; returns
  /// [PaymentSheetOutcome.cancelled] when the user dismisses the sheet.
  Future<PaymentSheetOutcome> present({required String clientSecret}) async {
    if (AppConfig.stripePublishableKey.isEmpty) {
      throw const PaymentException(
        'Payments are not configured for this build '
        '(STRIPE_PUBLISHABLE_KEY is missing).',
      );
    }
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: AppConfig.merchantDisplayName,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return PaymentSheetOutcome.completed;
    } on StripeException catch (exception) {
      if (exception.error.code == FailureCode.Canceled) {
        return PaymentSheetOutcome.cancelled;
      }
      throw PaymentException(
        exception.error.localizedMessage ??
            exception.error.message ??
            'The payment could not be completed.',
      );
    }
  }
}

final Provider<PaymentSheetService> paymentSheetServiceProvider =
    Provider<PaymentSheetService>((_) => const PaymentSheetService());

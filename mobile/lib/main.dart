import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'app.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Without a key the app still boots; the checkout flow surfaces the
  // missing configuration as a payment error instead of crashing natively.
  if (AppConfig.stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = AppConfig.stripePublishableKey;
  }
  runApp(
    ProviderScope(
      // Riverpod 3 silently retries failed providers with a backoff by
      // default. Every failing surface here has explicit retry UX (retry
      // buttons, pull-to-refresh), and a background retry would re-hammer a
      // struggling API and make failures look nondeterministic — so it is off.
      retry: (int retryCount, Object error) => null,
      child: const EcommerceApp(),
    ),
  );
}

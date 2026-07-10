import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

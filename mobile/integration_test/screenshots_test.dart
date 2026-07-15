import 'package:ecommerce_app/core/router/app_router.dart';
import 'package:ecommerce_app/features/cart/presentation/cart_screen.dart';
import 'package:ecommerce_app/features/catalog/presentation/product_detail_screen.dart';
import 'package:ecommerce_app/features/orders/presentation/orders_screen.dart';
import 'package:ecommerce_app/features/profile/presentation/profile_screen.dart';
import 'package:ecommerce_app/l10n/generated/app_localizations.dart';
import 'package:ecommerce_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

/// Walks the real app against a locally running, seeded API and captures the
/// screenshots embedded in the root README.
///
/// Prerequisites: `docker compose up -d`, the API on :3000 with the demo seed
/// applied (`npm run prisma:seed`), and an Android emulator. Then:
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart
void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Real-network flows never fully "settle" (spinners, image fades), so poll
  /// for the anchor widget instead of pumpAndSettle.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw StateError('Timed out waiting for $finder');
  }

  Future<void> shot(WidgetTester tester, String name) async {
    // Give network images a moment to decode before freezing the frame.
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await binding.takeScreenshot(name);
  }

  testWidgets('store walkthrough', (WidgetTester tester) async {
    await app.main();
    await tester.pump();
    // Android renders integration tests on a surface; screenshots need it
    // converted to an image-backed one first.
    await binding.convertFlutterSurfaceToImage();

    final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));

    // Fresh install: the session restore resolves to signed-out → login.
    await pumpUntil(tester, find.text(l10n.welcomeBack));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'ada@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Customer123!');
    await tester.pump();
    await shot(tester, 'mobile-01-login');

    await tester.tap(find.text(l10n.signIn));
    await pumpUntil(tester, find.text('Trek Travel Organizer'));
    await shot(tester, 'mobile-02-catalog');

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final GoRouter router = container.read(routerProvider);

    router.go(ProductDetailScreen.location('aurora-wireless-headphones'));
    await pumpUntil(tester, find.text(l10n.addToCart));
    await shot(tester, 'mobile-03-product-detail');

    await tester.tap(find.text(l10n.addToCart));

    router.go(CartScreen.path);
    await pumpUntil(tester, find.text('Aurora Wireless Headphones'));
    await shot(tester, 'mobile-04-cart');

    router.go(OrdersScreen.path);
    // Order cards show reference/date/total — anchor on the cards themselves.
    await pumpUntil(tester, find.byType(Card));
    await shot(tester, 'mobile-05-orders');

    // Newest first: Ada's seeded order being prepared today (Pulse speaker).
    await tester.tap(find.byType(Card).first);
    await pumpUntil(tester, find.text('Pulse Bluetooth Speaker'));
    await shot(tester, 'mobile-06-order-detail');

    router.go(ProfileScreen.path);
    await pumpUntil(tester, find.text('ada@example.com'));
    await shot(tester, 'mobile-07-profile');
  });
}

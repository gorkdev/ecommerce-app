import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/addresses/domain/address.dart';
import '../../features/addresses/presentation/address_form_screen.dart';
import '../../features/addresses/presentation/addresses_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

const Set<String> _publicRoutes = <String>{
  LoginScreen.path,
  RegisterScreen.path,
};

final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  // GoRouter is built once and re-runs `redirect` whenever this notifier fires.
  // Rebuilding the router on every auth change would tear down the navigator
  // and lose the whole back stack, so the auth state is bridged into a
  // Listenable instead of being watched directly.
  //
  // `ref.listen` does not fire immediately in Riverpod 3, hence the seed read.
  final ValueNotifier<AsyncValue<AuthUser?>> authListenable =
      ValueNotifier<AsyncValue<AuthUser?>>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, AsyncValue<AuthUser?> next) {
    authListenable.value = next;
  });

  final GoRouter router = GoRouter(
    initialLocation: SplashScreen.path,
    refreshListenable: authListenable,
    debugLogDiagnostics: kDebugMode,
    redirect: (_, GoRouterState state) {
      final AsyncValue<AuthUser?> auth = authListenable.value;
      final String location = state.matchedLocation;

      // Loading only ever means "restoring a stored session" — sign-in and
      // sign-up keep their progress state inside the form.
      if (auth.isLoading) {
        return location == SplashScreen.path ? null : SplashScreen.path;
      }

      final bool signedIn = auth.value != null;
      final bool onPublicRoute = _publicRoutes.contains(location);

      if (!signedIn) return onPublicRoute ? null : LoginScreen.path;
      if (onPublicRoute || location == SplashScreen.path) {
        return CatalogScreen.path;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: SplashScreen.path, builder: (_, _) => const SplashScreen()),
      GoRoute(path: LoginScreen.path, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: RegisterScreen.path,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(path: CatalogScreen.path, builder: (_, _) => const CatalogScreen()),
      GoRoute(
        path: ProductDetailScreen.path,
        builder: (_, GoRouterState state) =>
            ProductDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: CartScreen.path, builder: (_, _) => const CartScreen()),
      GoRoute(
        path: CheckoutScreen.path,
        builder: (_, _) => const CheckoutScreen(),
      ),
      GoRoute(
        path: FavoritesScreen.path,
        builder: (_, _) => const FavoritesScreen(),
      ),
      GoRoute(
        path: ProfileScreen.path,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: AddressesScreen.path,
        builder: (_, _) => const AddressesScreen(),
      ),
      GoRoute(
        path: AddressFormScreen.path,
        builder: (_, GoRouterState state) =>
            AddressFormScreen(initial: state.extra as Address?),
      ),
      GoRoute(path: OrdersScreen.path, builder: (_, _) => const OrdersScreen()),
      GoRoute(
        path: OrderDetailScreen.path,
        builder: (_, GoRouterState state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
    ],
  );

  // The router unsubscribes from the listenable, so it has to go first.
  ref.onDispose(() {
    router.dispose();
    authListenable.dispose();
  });

  return router;
});

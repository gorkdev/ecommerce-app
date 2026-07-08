import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/home_screen.dart';
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
        return HomeScreen.path;
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
      GoRoute(path: HomeScreen.path, builder: (_, _) => const HomeScreen()),
    ],
  );

  // The router unsubscribes from the listenable, so it has to go first.
  ref.onDispose(() {
    router.dispose();
    authListenable.dispose();
  });

  return router;
});

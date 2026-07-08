import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/session_expiry.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';

/// Owns *session* state, and only session state.
///
/// The value is the signed-in user, or `null` when signed out. Loading means
/// "we are restoring a session from disk" — nothing else, so the router can
/// safely treat it as "show the splash screen".
///
/// [login]/[register] deliberately do **not** flip the state to loading and do
/// **not** swallow errors into [AsyncError]: a failed sign-in is a form error,
/// not a broken session. They throw [ApiException] and let the screen render it.
final class AuthController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final expiry = ref.watch(sessionExpiryProvider);
    expiry.addListener(_handleSessionExpired);
    ref.onDispose(() => expiry.removeListener(_handleSessionExpired));

    return _restoreSession();
  }

  /// A stored access token is not proof of a live session — it may have expired
  /// while the app was closed. Ask the server; the interceptor will silently
  /// refresh if it can.
  Future<AuthUser?> _restoreSession() async {
    final storage = ref.read(tokenStorageProvider);
    if (await storage.readAccessToken() == null) return null;

    try {
      return await ref.read(authRepositoryProvider).me();
    } on ApiStatusException {
      // The server rejected the credentials outright and the interceptor could
      // not refresh them. They are dead — throw them away.
      await storage.clear();
      return null;
    } on ApiException {
      // Offline, or the server is down. The credentials may well still be good,
      // so keep them: launching the app on a train must not sign the user out.
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    await _startSession(session);
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .register(email: email, password: password, name: name);
    await _startSession(session);
  }

  /// Revoking the refresh token server-side is best effort: if the network is
  /// down, the local credentials still have to go.
  Future<void> logout() async {
    final storage = ref.read(tokenStorageProvider);
    final refreshToken = await storage.readRefreshToken();

    if (refreshToken != null) {
      try {
        await ref.read(authRepositoryProvider).logout(refreshToken);
      } on ApiException {
        // Ignored on purpose — see above.
      }
    }

    await storage.clear();
    state = const AsyncData<AuthUser?>(null);
  }

  Future<void> _startSession(AuthSession session) async {
    await ref
        .read(tokenStorageProvider)
        .saveTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
    state = AsyncData<AuthUser?>(session.user);
  }

  /// The HTTP client could not refresh — the tokens are already wiped.
  void _handleSessionExpired() {
    if (!ref.mounted) return;
    if (state.value == null) return;
    state = const AsyncData<AuthUser?>(null);
  }
}

final AsyncNotifierProvider<AuthController, AuthUser?> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);

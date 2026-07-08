import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-way channel from the network layer to whoever owns session state.
///
/// The HTTP client discovers that a session is dead (the refresh token was
/// rejected) but must not depend on the auth controller — the auth controller
/// already depends on the HTTP client. This notifier breaks that cycle.
final class SessionExpiryNotifier extends ChangeNotifier {
  void notifyExpired() => notifyListeners();
}

final Provider<SessionExpiryNotifier> sessionExpiryProvider =
    Provider<SessionExpiryNotifier>((ref) {
      final notifier = SessionExpiryNotifier();
      ref.onDispose(notifier.dispose);
      return notifier;
    });

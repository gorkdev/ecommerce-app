import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/push/app_messenger.dart';
import '../../../core/push/push_messaging_service.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/auth_controller.dart';
import '../../orders/presentation/order_detail_screen.dart';
import '../data/notifications_repository.dart';

/// Keeps this device's FCM token registered with the API while someone is
/// signed in, and turns incoming messages into navigation and banners.
///
/// Alive for the whole app run (app.dart watches it):
/// - sign-in (or a restored session) registers the device token
/// - a language change re-registers so the server pushes in the new language
/// - an FCM token rotation re-registers the fresh token
/// - a notification tap deep-links to the order it is about
/// - a foreground message becomes a snackbar with a "view" action
final class PushRegistrar extends Notifier<void> {
  String? _registeredToken;

  @override
  void build() {
    final PushMessagingService service = ref.watch(
      pushMessagingServiceProvider,
    );

    final List<StreamSubscription<Object?>> subscriptions =
        <StreamSubscription<Object?>>[];
    ref.onDispose(() {
      for (final StreamSubscription<Object?> subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    });

    // `ref.listen` does not fire immediately in Riverpod 3; a session that is
    // already restored is picked up by the seed read in [_start].
    ref.listen(authControllerProvider, (previous, next) {
      final bool wasSignedIn = previous?.value != null;
      final bool isSignedIn = next.value != null;
      if (!wasSignedIn && isSignedIn) unawaited(_register());
      // On sign-out only the local marker goes: the server-side row was
      // already removed by [unregisterDevice] while the credentials worked.
      if (wasSignedIn && !isSignedIn) _registeredToken = null;
    });

    // Language switches re-register so server-rendered copy follows along.
    ref.listen(localeControllerProvider, (_, _) {
      if (ref.read(authControllerProvider).value != null) {
        unawaited(_register());
      }
    });

    unawaited(_start(service, subscriptions));
  }

  Future<void> _start(
    PushMessagingService service,
    List<StreamSubscription<Object?>> subscriptions,
  ) async {
    if (!await service.initialize()) return;
    if (!ref.mounted) return;

    subscriptions.add(
      service.tokenRefreshStream().listen((_) => unawaited(_register())),
    );
    subscriptions.add(service.openedMessages().listen(_openOrder));
    subscriptions.add(service.foregroundMessages().listen(_showBanner));

    if (ref.read(authControllerProvider).value != null) {
      await _register();
    }

    // A tap on a tray notification may be what cold-started the app. Wait
    // out the session restore first: while it runs, the router redirects
    // everything to the splash screen and would drop the deep link.
    try {
      await ref.read(authControllerProvider.future);
    } on Object {
      // A failed restore parks its error in the controller's state; the
      // navigation below is still worth attempting.
    }
    if (!ref.mounted) return;
    final PushMessage? initial = await service.initialMessage();
    if (initial != null && ref.mounted) {
      _openOrder(initial);
    }
  }

  Future<void> _register() async {
    final String? token = await ref
        .read(pushMessagingServiceProvider)
        .getToken();
    if (token == null || !ref.mounted) return;
    // The account may have signed out while the token was being fetched.
    if (ref.read(authControllerProvider).value == null) return;

    final String locale =
        ref.read(localeControllerProvider)?.languageCode ??
        ui.PlatformDispatcher.instance.locale.languageCode;
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .registerDeviceToken(
            token: token,
            platform: defaultTargetPlatform == TargetPlatform.iOS
                ? 'ios'
                : 'android',
            locale: locale,
          );
      _registeredToken = token;
    } on ApiException {
      // Best effort — registration retries on the next sign-in or app start.
    }
  }

  /// Called by the sign-out flow *before* the credentials are dropped —
  /// afterwards the DELETE could no longer authenticate.
  Future<void> unregisterDevice() async {
    final String? token = _registeredToken;
    _registeredToken = null;
    if (token == null) return;
    try {
      await ref.read(notificationsRepositoryProvider).removeDeviceToken(token);
    } on ApiException {
      // Best effort: an unreachable server must not block signing out. The
      // token follows the next account that signs in on this device anyway.
    }
  }

  void _openOrder(PushMessage message) {
    if (!ref.mounted) return;
    final String? orderId = message.data['orderId'];
    if (message.data['type'] != 'order-status' ||
        orderId == null ||
        orderId.isEmpty) {
      return;
    }
    ref.read(routerProvider).push(OrderDetailScreen.location(orderId));
  }

  void _showBanner(PushMessage message) {
    if (!ref.mounted) return;
    final String? title = message.title;
    if (title == null) return;
    final ScaffoldMessengerState? messenger = ref
        .read(scaffoldMessengerKeyProvider)
        .currentState;
    if (messenger == null) return;

    SnackBarAction? action;
    final String? orderId = message.data['orderId'];
    if (message.data['type'] == 'order-status' &&
        orderId != null &&
        orderId.isNotEmpty) {
      action = SnackBarAction(
        label: _l10n().view,
        onPressed: () =>
            ref.read(routerProvider).push(OrderDetailScreen.location(orderId)),
      );
    }

    messenger.showSnackBar(
      SnackBar(
        // Title and body were already rendered server-side in this device's
        // registered language.
        content: Text(
          message.body == null ? title : '$title — ${message.body}',
        ),
        action: action,
      ),
    );
  }

  /// Strings for UI built outside the widget tree (the snackbar action).
  AppLocalizations _l10n() {
    final ui.Locale locale =
        ref.read(localeControllerProvider) ??
        ui.PlatformDispatcher.instance.locale;
    try {
      return lookupAppLocalizations(locale);
    } on FlutterError {
      return lookupAppLocalizations(const ui.Locale('en'));
    }
  }
}

final NotifierProvider<PushRegistrar, void> pushRegistrarProvider =
    NotifierProvider<PushRegistrar, void>(PushRegistrar.new);

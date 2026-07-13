import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An FCM message reduced to the parts the app acts on.
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const <String, String>{}});

  final String? title;
  final String? body;

  /// The server sends `type`, `orderId` and `status` here for deep links.
  final Map<String, String> data;
}

/// The single seam that touches the Firebase SDK — the push mirror of
/// `PaymentSheetService` for Stripe. Firebase needs per-developer config
/// files (google-services.json / GoogleService-Info.plist, both gitignored),
/// so every call degrades to a no-op when they are absent: the app runs,
/// push simply stays off.
///
/// Left open (not `final`) so tests can stand in a mock for it.
class PushMessagingService {
  Future<bool>? _initialization;
  bool _supported = false;

  /// Whether Firebase booted successfully. `false` until [initialize] ran.
  bool get supported => _supported;

  /// Idempotent: the first call boots Firebase, later callers await the same
  /// future. Returns false (never throws) when Firebase is not configured.
  Future<bool> initialize() => _initialization ??= _initialize();

  Future<bool> _initialize() async {
    try {
      await Firebase.initializeApp();
      _supported = true;
    } catch (error) {
      debugPrint(
        'Firebase is not configured for this build — push disabled ($error)',
      );
    }
    return _supported;
  }

  /// Asks for notification permission and returns this install's FCM token.
  /// Null when push is unsupported, permission was denied, or no token is
  /// available (e.g. an emulator without Play services).
  Future<String?> getToken() async {
    if (!await initialize()) return null;
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (error) {
      debugPrint('Could not obtain an FCM token: $error');
      return null;
    }
  }

  /// Fires when FCM rotates the token; the new value must be re-registered.
  Stream<String> tokenRefreshStream() {
    if (!_supported) return const Stream<String>.empty();
    return FirebaseMessaging.instance.onTokenRefresh;
  }

  /// Messages arriving while the app is on screen (no system tray involved).
  Stream<PushMessage> foregroundMessages() {
    if (!_supported) return const Stream<PushMessage>.empty();
    return FirebaseMessaging.onMessage.map(_toPushMessage);
  }

  /// Tray-notification taps that brought the app back from the background.
  Stream<PushMessage> openedMessages() {
    if (!_supported) return const Stream<PushMessage>.empty();
    return FirebaseMessaging.onMessageOpenedApp.map(_toPushMessage);
  }

  /// The tray-notification tap that cold-started the app, if any.
  Future<PushMessage?> initialMessage() async {
    if (!_supported) return null;
    final RemoteMessage? message = await FirebaseMessaging.instance
        .getInitialMessage();
    return message == null ? null : _toPushMessage(message);
  }

  PushMessage _toPushMessage(RemoteMessage message) => PushMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    data: message.data.map(
      (String key, dynamic value) =>
          MapEntry<String, String>(key, value.toString()),
    ),
  );
}

final Provider<PushMessagingService> pushMessagingServiceProvider =
    Provider<PushMessagingService>((_) => PushMessagingService());

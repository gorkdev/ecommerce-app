import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'session_expiry.dart';

BaseOptions _baseOptions() => BaseOptions(
  baseUrl: AppConfig.apiBaseUrl,
  connectTimeout: AppConfig.connectTimeout,
  receiveTimeout: AppConfig.receiveTimeout,
  contentType: Headers.jsonContentType,
  responseType: ResponseType.json,
);

/// The application's HTTP client: authenticated, self-refreshing.
///
/// A second, interceptor-free client is handed to [AuthInterceptor] for the
/// refresh call and the replayed request, so neither can recurse back through
/// the interceptor chain.
final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final bareClient = Dio(_baseOptions());
  final client = Dio(_baseOptions());

  client.interceptors.add(
    AuthInterceptor(
      storage: ref.watch(tokenStorageProvider),
      client: bareClient,
      onSessionExpired: () async =>
          ref.read(sessionExpiryProvider).notifyExpired(),
    ),
  );

  ref.onDispose(() {
    client.close();
    bareClient.close();
  });

  return client;
});

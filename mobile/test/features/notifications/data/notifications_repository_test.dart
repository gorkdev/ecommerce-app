import 'package:dio/dio.dart';
import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/notifications/data/notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_adapter.dart';

({NotificationsRepository repository, FakeHttpAdapter adapter}) _build(
  FakeResponder responder,
) {
  final FakeHttpAdapter adapter = FakeHttpAdapter(responder);
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test',
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = adapter;
  return (repository: NotificationsRepository(dio), adapter: adapter);
}

void main() {
  test('register POSTs the token with its platform and language', () async {
    final sut = _build(
      (_) => FakeHttpAdapter.json(201, <String, Object?>{
        'id': 'dt_1',
        'token': 'fcm-token-1',
        'platform': 'android',
        'locale': 'tr',
      }),
    );

    await sut.repository.registerDeviceToken(
      token: 'fcm-token-1',
      platform: 'android',
      locale: 'tr',
    );

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/notifications/tokens');
    expect(request.method, 'POST');
    expect(request.data, <String, String>{
      'token': 'fcm-token-1',
      'platform': 'android',
      'locale': 'tr',
    });
  });

  test('remove DELETEs the URL-encoded token and accepts the 204', () async {
    final sut = _build((_) => FakeHttpAdapter.noContent());

    // Real FCM tokens contain ":" — it must survive as a path segment.
    await sut.repository.removeDeviceToken('device:APA91b');

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/notifications/tokens/device%3AAPA91b');
  });

  test('surfaces server rejections as ApiStatusException', () async {
    final sut = _build(
      (_) => FakeHttpAdapter.json(400, <String, Object?>{
        'statusCode': 400,
        'message': 'platform must be one of the following values: android, ios',
        'error': 'Bad Request',
      }),
    );

    await expectLater(
      sut.repository.registerDeviceToken(
        token: 'fcm-token-1',
        platform: 'windows',
        locale: 'en',
      ),
      throwsA(isA<ApiStatusException>()),
    );
  });
}

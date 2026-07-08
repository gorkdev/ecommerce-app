import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Decides what the "server" answers for a given request.
typedef FakeResponder = FutureOr<ResponseBody> Function(RequestOptions options);

/// A Dio transport that answers from a closure and records what it was asked.
///
/// Preferred over a mocking package here because the interceptor tests need to
/// vary the response by request *and* count how many times a path was hit.
final class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this._responder);

  final FakeResponder _responder;

  final List<RequestOptions> requests = <RequestOptions>[];

  Iterable<RequestOptions> requestsTo(String path) =>
      requests.where((RequestOptions request) => request.path == path);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _responder(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(int statusCode, Object? body) =>
      ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  static ResponseBody noContent() => ResponseBody.fromString(
    '',
    204,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

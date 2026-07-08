import 'package:dio/dio.dart';

/// A failure the UI can render.
///
/// Repositories translate every [DioException] into one of these so that no
/// layer above `data/` has to know the app talks HTTP, let alone that it uses
/// Dio.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  /// Human-readable, safe to show in a snackbar.
  final String message;

  /// Maps Dio's failure taxonomy onto ours.
  factory ApiException.from(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkException('The server took too long to respond.');
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badCertificate:
        return const NetworkException('The server certificate was rejected.');
      case DioExceptionType.cancel:
        return const UnexpectedApiException('The request was cancelled.');
      case DioExceptionType.badResponse:
        final response = error.response;
        return ApiStatusException(
          response?.statusCode ?? 0,
          _messageFrom(response?.data) ?? 'The request failed.',
        );
      case DioExceptionType.unknown:
        return UnexpectedApiException(error.message ?? 'Something went wrong.');
    }
  }

  /// Nest replies with `{ statusCode, message, error }`, where `message` is a
  /// string for thrown exceptions and a list of strings for DTO validation
  /// failures. Surface the first line either way.
  static String? _messageFrom(Object? body) {
    if (body is! Map) return null;
    final message = body['message'];
    if (message is String && message.isNotEmpty) return message;
    if (message is List && message.isNotEmpty) return message.first.toString();
    return null;
  }

  @override
  String toString() => '$runtimeType: $message';
}

/// The request never reached the server: offline, DNS failure, timeout, TLS.
final class NetworkException extends ApiException {
  const NetworkException([super.message = 'No connection to the server.']);
}

/// The server answered, but with a non-2xx status.
final class ApiStatusException extends ApiException {
  const ApiStatusException(this.statusCode, super.message);

  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
}

/// Anything we could not classify — a malformed payload, a cancelled request.
final class UnexpectedApiException extends ApiException {
  const UnexpectedApiException(super.message);
}

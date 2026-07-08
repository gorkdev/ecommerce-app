import 'package:dio/dio.dart';
import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dioError(
  DioExceptionType type, {
  int? statusCode,
  Object? body,
  String? message,
}) {
  final RequestOptions options = RequestOptions(path: '/anything');
  return DioException(
    requestOptions: options,
    type: type,
    message: message,
    response: statusCode == null
        ? null
        : Response<Object?>(
            requestOptions: options,
            statusCode: statusCode,
            data: body,
          ),
  );
}

void main() {
  group('ApiException.from', () {
    test('maps every timeout flavour to a NetworkException', () {
      for (final DioExceptionType type in <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        final ApiException exception = ApiException.from(_dioError(type));
        expect(exception, isA<NetworkException>(), reason: '$type');
        expect(exception.message, 'The server took too long to respond.');
      }
    });

    test('maps a dead connection to a NetworkException', () {
      final ApiException exception = ApiException.from(
        _dioError(DioExceptionType.connectionError),
      );
      expect(exception, isA<NetworkException>());
      expect(exception.message, 'No connection to the server.');
    });

    test('maps a rejected certificate to a NetworkException', () {
      expect(
        ApiException.from(_dioError(DioExceptionType.badCertificate)),
        isA<NetworkException>(),
      );
    });

    test('maps a cancellation to an UnexpectedApiException', () {
      expect(
        ApiException.from(_dioError(DioExceptionType.cancel)),
        isA<UnexpectedApiException>(),
      );
    });

    test('carries the status code and the message Nest sent', () {
      final ApiException exception = ApiException.from(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 401,
          body: <String, Object?>{
            'statusCode': 401,
            'message': 'Invalid credentials',
            'error': 'Unauthorized',
          },
        ),
      );

      expect(exception, isA<ApiStatusException>());
      final ApiStatusException status = exception as ApiStatusException;
      expect(status.statusCode, 401);
      expect(status.message, 'Invalid credentials');
      expect(status.isUnauthorized, isTrue);
      expect(status.isForbidden, isFalse);
    });

    test('surfaces the first line of a DTO validation failure', () {
      // Nest's ValidationPipe returns `message` as a list of strings.
      final ApiException exception = ApiException.from(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 400,
          body: <String, Object?>{
            'statusCode': 400,
            'message': <String>[
              'email must be an email',
              'password must be longer than or equal to 8 characters',
            ],
            'error': 'Bad Request',
          },
        ),
      );

      expect(exception.message, 'email must be an email');
    });

    test('falls back to a generic message when the body is unhelpful', () {
      final ApiException exception = ApiException.from(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 500,
          body: '<html>Bad Gateway</html>',
        ),
      );

      expect(exception, isA<ApiStatusException>());
      expect((exception as ApiStatusException).statusCode, 500);
      expect(exception.message, 'The request failed.');
    });

    test('exposes the conflict and not-found predicates', () {
      const ApiStatusException conflict = ApiStatusException(409, 'Taken');
      const ApiStatusException missing = ApiStatusException(404, 'Gone');
      expect(conflict.isConflict, isTrue);
      expect(missing.isNotFound, isTrue);
      expect(missing.isConflict, isFalse);
    });

    test('keeps Dio\'s own message for unclassified failures', () {
      final ApiException exception = ApiException.from(
        _dioError(DioExceptionType.unknown, message: 'Socket closed'),
      );
      expect(exception, isA<UnexpectedApiException>());
      expect(exception.message, 'Socket closed');
    });
  });
}

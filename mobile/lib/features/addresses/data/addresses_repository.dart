import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/address.dart';

/// Typed client for `/addresses`.
///
/// Left open (not `final`) so tests can stand in a mock for it.
class AddressesRepository {
  const AddressesRepository(this._dio);

  final Dio _dio;

  /// The caller's addresses, default first (server-sorted).
  Future<List<Address>> list() {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>('/addresses');
      final List<dynamic> body = response.data ?? const <dynamic>[];
      return body
          .map((address) => Address.fromJson(address as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Address> create(AddressInput input) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/addresses',
        data: input.toJson(),
      );
      return Address.fromJson(_requireBody(response));
    });
  }

  Future<Address> update(String id, AddressInput input) {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/addresses/$id',
        data: input.toJson(),
      );
      return Address.fromJson(_requireBody(response));
    });
  }

  /// Moves the default flag onto [id]; the server unsets the previous one.
  Future<Address> setDefault(String id) {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/addresses/$id',
        data: const <String, Object>{'isDefault': true},
      );
      return Address.fromJson(_requireBody(response));
    });
  }

  /// Fails with a 409 when orders reference the address.
  Future<void> remove(String id) {
    return _guard(() => _dio.delete<void>('/addresses/$id'));
  }

  Map<String, dynamic> _requireBody(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data == null) {
      throw const UnexpectedApiException('The server returned an empty body.');
    }
    return data;
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}

final Provider<AddressesRepository> addressesRepositoryProvider =
    Provider<AddressesRepository>(
      (ref) => AddressesRepository(ref.watch(dioProvider)),
    );

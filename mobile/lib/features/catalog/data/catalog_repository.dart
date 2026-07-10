import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/category.dart';
import '../domain/paginated.dart';
import '../domain/product.dart';
import '../domain/product_query.dart';

/// Typed client for the public catalog endpoints.
///
/// Everything above this layer sees domain types and [ApiException]; Dio
/// stops here.
///
/// Left open (not `final`) so tests can stand in a mock for it.
class CatalogRepository {
  const CatalogRepository(this._dio);

  final Dio _dio;

  /// The full category forest, children nested under parents.
  Future<List<Category>> fetchCategories() {
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>('/categories');
      final data = response.data;
      if (data == null) {
        throw const UnexpectedApiException('The server returned an empty body.');
      }
      return data
          .map((node) => Category.fromJson(node as Map<String, dynamic>))
          .toList();
    });
  }

  /// One page of active products matching [query].
  Future<Paginated<Product>> fetchProducts(ProductQuery query) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/products',
        queryParameters: query.toQueryParameters(),
      );
      return Paginated<Product>.fromJson(
        _requireBody(response),
        Product.fromJson,
      );
    });
  }

  /// The product detail is addressed by slug, not id — mirrors the web URLs.
  Future<Product> fetchProduct(String slug) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/products/$slug');
      return Product.fromJson(_requireBody(response));
    });
  }

  /// A 2xx with no JSON body would otherwise blow up somewhere far from here.
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

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>(
      (ref) => CatalogRepository(ref.watch(dioProvider)),
    );

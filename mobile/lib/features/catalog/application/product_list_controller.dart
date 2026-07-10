import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/catalog_repository.dart';
import '../domain/paginated.dart';
import '../domain/product.dart';
import '../domain/product_query.dart';

/// Accumulated catalog pages plus enough metadata to keep paginating.
final class ProductListState {
  const ProductListState({
    required this.products,
    required this.page,
    required this.totalPages,
    required this.total,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Product> products;
  final int page;
  final int totalPages;
  final int total;

  /// A next page is being appended (the grid shows a bottom spinner).
  final bool isLoadingMore;

  /// The last append failed. Kept out of [AsyncError] on purpose: the products
  /// already on screen are still perfectly valid.
  final bool loadMoreFailed;

  bool get hasMore => page < totalPages;

  ProductListState copyWith({bool? isLoadingMore, bool? loadMoreFailed}) =>
      ProductListState(
        products: products,
        page: page,
        totalPages: totalPages,
        total: total,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

/// Owns the product listing: the active query and the pages fetched so far.
///
/// Every mutation bumps [_operation]; a response is only applied when its
/// operation is still the latest, so a stale search result can never
/// overwrite a newer one, no matter how the network reorders replies.
final class ProductListController extends AsyncNotifier<ProductListState> {
  ProductQuery _query = const ProductQuery();
  int _operation = 0;

  /// The filters currently applied — the UI reads this to seed its controls.
  ProductQuery get query => _query;

  @override
  Future<ProductListState> build() {
    // A fresh build (first mount or provider refresh) starts from scratch.
    _query = const ProductQuery();
    _operation++;
    return _fetchFirstPage(_query);
  }

  /// Replaces the query and reloads from page 1. No-op when nothing changed,
  /// so an unedited search field cannot cause a spurious reload.
  Future<void> apply(ProductQuery query) {
    if (query == _query) return Future<void>.value();
    _query = query;
    return _reload();
  }

  /// Re-runs the current query (error retry, pull-to-refresh).
  Future<void> reload() => _reload();

  /// Appends the next page, if there is one and none is already on its way.
  Future<void> loadMore() async {
    final ProductListState? current = state.value;
    if (current == null ||
        state.isLoading ||
        current.isLoadingMore ||
        !current.hasMore) {
      return;
    }

    final int operation = ++_operation;
    state = AsyncData<ProductListState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final Paginated<Product> next = await ref
          .read(catalogRepositoryProvider)
          .fetchProducts(_query.pageAt(current.page + 1));
      if (operation != _operation || !ref.mounted) return;
      state = AsyncData<ProductListState>(
        ProductListState(
          products: <Product>[...current.products, ...next.items],
          page: next.page,
          totalPages: next.totalPages,
          total: next.total,
        ),
      );
    } on ApiException {
      if (operation != _operation || !ref.mounted) return;
      state = AsyncData<ProductListState>(
        current.copyWith(isLoadingMore: false, loadMoreFailed: true),
      );
    }
  }

  Future<void> _reload() async {
    final int operation = ++_operation;
    state = const AsyncLoading<ProductListState>();
    final AsyncValue<ProductListState> next =
        await AsyncValue.guard<ProductListState>(
          () => _fetchFirstPage(_query),
        );
    if (operation != _operation || !ref.mounted) return;
    state = next;
  }

  Future<ProductListState> _fetchFirstPage(ProductQuery query) async {
    final Paginated<Product> page = await ref
        .read(catalogRepositoryProvider)
        .fetchProducts(query.pageAt(1));
    return ProductListState(
      products: page.items,
      page: page.page,
      totalPages: page.totalPages,
      total: page.total,
    );
  }
}

final AsyncNotifierProvider<ProductListController, ProductListState>
productListControllerProvider =
    AsyncNotifierProvider<ProductListController, ProductListState>(
      ProductListController.new,
    );

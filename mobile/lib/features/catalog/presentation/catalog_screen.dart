import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/catalog_providers.dart';
import '../application/product_list_controller.dart';
import '../domain/category.dart';
import '../domain/product_query.dart';
import 'widgets/price_filter_sheet.dart';
import 'widgets/product_card.dart';

/// The storefront landing screen: search, filters and the product grid.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  static const String path = '/';

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  static const Duration _searchDebounce = Duration(milliseconds: 400);

  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  ProductListController get _controller =>
      ref.read(productListControllerProvider.notifier);

  void _maybeLoadMore() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _controller.loadMore();
    }
  }

  /// Debounced so a fast typist triggers one request, not one per keystroke.
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      _controller.apply(_controller.query.withSearch(text));
    });
  }

  Future<void> _openPriceFilter() async {
    final ProductQuery query = _controller.query;
    final PriceRange? range = await showModalBottomSheet<PriceRange>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PriceFilterSheet(
        initialMin: query.minPrice,
        initialMax: query.maxPrice,
      ),
    );
    // null = dismissed without choosing; leave the filter as it was.
    if (range == null) return;
    await _controller.apply(query.withPriceRange(range.min, range.max));
  }

  @override
  Widget build(BuildContext context) {
    // Failing to append a page must not blank the grid — surface it softly.
    ref.listen(productListControllerProvider, (
      AsyncValue<ProductListState>? previous,
      AsyncValue<ProductListState> next,
    ) {
      final bool failedNow = next.value?.loadMoreFailed ?? false;
      final bool failedBefore = previous?.value?.loadMoreFailed ?? false;
      if (failedNow && !failedBefore) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not load more products.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _controller.loadMore(),
            ),
          ),
        );
      }
    });

    final AsyncValue<ProductListState> listState = ref.watch(
      productListControllerProvider,
    );
    final ProductQuery query = _controller.query;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storefront'),
        actions: <Widget>[
          PopupMenuButton<ProductSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (ProductSort sort) =>
                _controller.apply(_controller.query.withSort(sort)),
            itemBuilder: (_) => <PopupMenuEntry<ProductSort>>[
              _sortItem(ProductSort.newest, 'Newest'),
              _sortItem(ProductSort.priceAsc, 'Price: low to high'),
              _sortItem(ProductSort.priceDesc, 'Price: high to low'),
            ],
          ),
          IconButton(
            tooltip: 'Price filter',
            onPressed: _openPriceFilter,
            icon: Badge(
              smallSize: 8,
              isLabelVisible: query.hasPriceFilter,
              child: const Icon(Icons.tune),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search products',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ListenableBuilder(
                  listenable: _search,
                  builder: (_, _) => _search.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
              ),
            ),
          ),
          _CategoryChips(
            selectedId: query.categoryId,
            onSelected: (String? categoryId) =>
                _controller.apply(_controller.query.withCategory(categoryId)),
          ),
          Expanded(child: _buildBody(listState)),
        ],
      ),
    );
  }

  PopupMenuItem<ProductSort> _sortItem(ProductSort sort, String label) {
    final bool active = _controller.query.sort == sort;
    return CheckedPopupMenuItem<ProductSort>(
      value: sort,
      checked: active,
      child: Text(label),
    );
  }

  Widget _buildBody(AsyncValue<ProductListState> listState) {
    final ProductListState? data = listState.value;

    if (data == null) {
      if (listState.hasError) {
        return _CatalogError(
          error: listState.error,
          onRetry: () => _controller.reload(),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (data.products.isEmpty) {
      return const _EmptyCatalog();
    }

    return RefreshIndicator(
      onRefresh: () => _controller.reload(),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, int index) => ProductCard(data.products[index]),
                childCount: data.products.length,
              ),
            ),
          ),
          if (data.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.selectedId, required this.onSelected});

  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Category>> categories = ref.watch(
      categoriesProvider,
    );
    final List<Category>? roots = categories.value;

    // While loading, hold the row's height so the grid does not jump; if the
    // call failed, the catalog is still browsable without chips.
    if (roots == null) {
      return SizedBox(height: categories.hasError ? 0 : 48);
    }
    final List<Category> flat = Category.flatten(roots);
    if (flat.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: flat.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, int index) {
          if (index == 0) {
            return ChoiceChip(
              label: const Text('All'),
              selected: selectedId == null,
              onSelected: (_) => onSelected(null),
            );
          }
          final Category category = flat[index - 1];
          return ChoiceChip(
            label: Text(category.name),
            selected: selectedId == category.id,
            onSelected: (_) => onSelected(category.id),
          );
        },
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('No products found', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Try a different search or clear the filters.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String message = error is ApiException
        ? (error! as ApiException).message
        : 'Something went wrong.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.wifi_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

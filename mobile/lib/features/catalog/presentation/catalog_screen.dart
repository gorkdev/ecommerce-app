import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
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
            content: Text(context.l10n.couldNotLoadMore),
            action: SnackBarAction(
              label: context.l10n.retry,
              onPressed: () => _controller.loadMore(),
            ),
          ),
        );
      }
    });

    final ThemeData theme = Theme.of(context);
    final AsyncValue<ProductListState> listState = ref.watch(
      productListControllerProvider,
    );
    final ProductQuery query = _controller.query;
    final AppLocalizations l10n = context.l10n;
    // First name only: the greeting is casual by design.
    final String? name = ref
        .watch(authControllerProvider)
        .value
        ?.name
        .split(' ')
        .first;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space5,
                AppTokens.space4,
                AppTokens.space3,
                0,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      name == null ? l10n.appTitle : l10n.greeting(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  PopupMenuButton<ProductSort>(
                    icon: const Icon(Icons.sort),
                    tooltip: l10n.sort,
                    onSelected: (ProductSort sort) =>
                        _controller.apply(_controller.query.withSort(sort)),
                    itemBuilder: (_) => <PopupMenuEntry<ProductSort>>[
                      _sortItem(ProductSort.newest, l10n.sortNewest),
                      _sortItem(ProductSort.priceAsc, l10n.sortPriceLowHigh),
                      _sortItem(ProductSort.priceDesc, l10n.sortPriceHighLow),
                    ],
                  ),
                  IconButton(
                    tooltip: l10n.priceFilter,
                    onPressed: _openPriceFilter,
                    icon: Badge(
                      smallSize: 8,
                      isLabelVisible: query.hasPriceFilter,
                      child: const Icon(Icons.tune),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space5,
                AppTokens.space3,
                AppTokens.space5,
                AppTokens.space1,
              ),
              child: TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchProducts,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ListenableBuilder(
                    listenable: _search,
                    builder: (_, _) => _search.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: l10n.clearSearch,
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
              onSelected: (String? categoryId) => _controller.apply(
                _controller.query.withCategory(categoryId),
              ),
            ),
            Expanded(child: _buildBody(listState)),
          ],
        ),
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
        return ErrorView(
          error: listState.error,
          onRetry: () => _controller.reload(),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (data.products.isEmpty) {
      return EmptyView(
        icon: Icons.search_off_outlined,
        title: context.l10n.noProductsFound,
        subtitle: context.l10n.noProductsHint,
      );
    }

    // The promo banner only fronts the unfiltered storefront; during a
    // search or filter it would push the results the user asked for down.
    final bool showBanner =
        _controller.query.search == null && !_controller.query.hasPriceFilter;

    return RefreshIndicator(
      onRefresh: () => _controller.reload(),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          if (showBanner)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.space5,
                AppTokens.space3,
                AppTokens.space5,
                0,
              ),
              sliver: SliverToBoxAdapter(child: _PromoBanner()),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(AppTokens.space5),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: AppTokens.space4,
                crossAxisSpacing: AppTokens.space4,
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

/// The storefront's standing welcome offer. The code matches the seeded
/// WELCOME10 coupon, so tapping through checkout with it actually works.
class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  static const String _code = 'WELCOME10';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space5),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.promoBannerTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: AppTokens.space1),
                Text(
                  l10n.promoBannerBody(_code),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space3),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space3,
              vertical: AppTokens.space2,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _code,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
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
              label: Text(context.l10n.allCategories),
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


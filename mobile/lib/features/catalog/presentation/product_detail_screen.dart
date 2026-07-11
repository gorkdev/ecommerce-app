import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/error_view.dart';
import '../../cart/application/cart_controller.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../favorites/application/favorites_controller.dart';
import '../../reviews/application/reviews_providers.dart';
import '../../reviews/domain/review.dart';
import '../../reviews/presentation/reviews_screen.dart';
import '../../reviews/presentation/widgets/rating_stars.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';
import '../domain/product_summary.dart';
import 'widgets/product_price.dart';

/// Full product page: gallery, pricing, stock and description.
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({required this.slug, super.key});

  static const String path = '/product/:slug';

  static String location(String slug) => '/product/$slug';

  final String slug;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _galleryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Product> detail = ref.watch(
      productDetailProvider(widget.slug),
    );
    final Product? product = detail.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(product?.name ?? 'Product'),
        actions: <Widget>[
          if (product != null) _FavoriteAction(product),
        ],
      ),
      bottomNavigationBar: product == null ? null : _AddToCartBar(product),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) {
          final bool gone =
              error is ApiStatusException && error.isNotFound;
          return ErrorView(
            error: error,
            icon: gone ? Icons.inventory_2_outlined : Icons.wifi_off_outlined,
            message: gone ? 'This product is no longer available.' : null,
            onRetry: gone
                ? null
                : () => ref.invalidate(productDetailProvider(widget.slug)),
          );
        },
        data: (Product product) => ListView(
          children: <Widget>[
            _Gallery(
              product: product,
              index: _galleryIndex,
              onPageChanged: (int index) =>
                  setState(() => _galleryIndex = index),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: _DetailBody(product),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody(this.product);

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int? discount = product.discountPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (product.category != null) ...<Widget>[
          Text(
            product.category!.name.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(product.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            ProductPrice(
              product,
              priceStyle: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (discount != null) ...<Widget>[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '-$discount%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Icon(
              product.inStock
                  ? Icons.check_circle_outline
                  : Icons.remove_circle_outline,
              size: 18,
              color: product.inStock
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: 6),
            Text(
              product.inStock ? 'In stock' : 'Out of stock',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: product.inStock
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewsTile(product),
        const SizedBox(height: 12),
        Text('Description', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          product.description,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

/// One-line rating summary that opens the reviews screen.
class _ReviewsTile extends ConsumerWidget {
  const _ReviewsTile(this.product);

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final RatingSummary? summary = ref
        .watch(productReviewsProvider(product.id))
        .value
        ?.summary;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(
        ReviewsScreen.location(product.id),
        extra: product.name,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            RatingStars(summary?.average ?? 0),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary == null
                    ? 'Reviews'
                    : summary.count == 0
                    ? 'No reviews yet'
                    : '${summary.average.toStringAsFixed(1)} · '
                          '${summary.count == 1 ? '1 review' : '${summary.count} reviews'}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.product,
    required this.index,
    required this.onPageChanged,
  });

  final Product product;
  final int index;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<ProductImage> images = product.images;

    final Widget placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    return Column(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1,
          child: images.isEmpty
              ? placeholder
              : PageView.builder(
                  itemCount: images.length,
                  onPageChanged: onPageChanged,
                  itemBuilder: (_, int page) => Image.network(
                    AppConfig.resolveMediaUrl(images[page].url),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  ),
                ),
        ),
        if (images.length > 1) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(images.length, (int dot) {
              final bool active = dot == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _FavoriteAction extends ConsumerWidget {
  const _FavoriteAction(this.product);

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bool saved = ref
        .watch(favoriteProductIdsProvider)
        .contains(product.id);

    return IconButton(
      tooltip: saved ? 'Remove from favorites' : 'Add to favorites',
      icon: Icon(
        saved ? Icons.favorite : Icons.favorite_outline,
        color: saved ? theme.colorScheme.error : null,
      ),
      onPressed: () => _toggle(context, ref),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(favoritesControllerProvider.notifier)
          .toggle(ProductSummary.of(product));
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// Sticky "Add to cart" bar. Adding always puts one unit in; quantities are
/// adjusted in the cart itself.
class _AddToCartBar extends ConsumerStatefulWidget {
  const _AddToCartBar(this.product);

  final Product product;

  @override
  ConsumerState<_AddToCartBar> createState() => _AddToCartBarState();
}

class _AddToCartBarState extends ConsumerState<_AddToCartBar> {
  bool _busy = false;

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      await ref.read(cartControllerProvider.notifier).add(widget.product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Added to cart'),
          action: SnackBarAction(
            label: 'View cart',
            onPressed: () => context.push(CartScreen.path),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool inStock = widget.product.inStock;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton(
            onPressed: inStock && !_busy ? _add : null,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(inStock ? 'Add to cart' : 'Out of stock'),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/formatting/date_formatter.dart';
import '../../../shared/formatting/price_formatter.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../cart/application/cart_controller.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../favorites/application/favorites_controller.dart';
import '../../reviews/application/reviews_providers.dart';
import '../../reviews/domain/review.dart';
import '../../reviews/presentation/reviews_screen.dart';
import '../../reviews/presentation/widgets/rating_chip.dart';
import '../../reviews/presentation/widgets/rating_stars.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';
import '../domain/product_summary.dart';
import 'widgets/product_price.dart';

/// How few units still count as "hurry": under this the page nudges.
const int _lowStockThreshold = 5;

/// Full product page: edge-to-edge gallery with floating actions, pricing,
/// stock, description, a reviews preview and a sticky add-to-cart bar.
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
      bottomNavigationBar: product == null ? null : _AddToCartBar(product),
      body: Stack(
        children: <Widget>[
          detail.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, _) {
              final bool gone = error is ApiStatusException && error.isNotFound;
              return ErrorView(
                error: error,
                icon: gone
                    ? Icons.inventory_2_outlined
                    : Icons.wifi_off_outlined,
                message: gone ? context.l10n.productUnavailable : null,
                onRetry: gone
                    ? null
                    : () => ref.invalidate(productDetailProvider(widget.slug)),
              );
            },
            data: (Product product) => ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                _Gallery(
                  product: product,
                  index: _galleryIndex,
                  onPageChanged: (int index) =>
                      setState(() => _galleryIndex = index),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.space5,
                    AppTokens.space5,
                    AppTokens.space5,
                    AppTokens.space7,
                  ),
                  child: _DetailBody(product),
                ),
              ],
            ),
          ),
          // Floating back + heart, always reachable — also over the gallery.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space3,
                vertical: AppTokens.space1,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _FloatingCircleButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    icon: Icons.arrow_back,
                    onPressed: () => context.pop(),
                  ),
                  if (product != null) _FavoriteAction(product),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted circular icon button that stays readable over photography.
class _FloatingCircleButton extends StatelessWidget {
  const _FloatingCircleButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: color ?? theme.colorScheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody(this.product);

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);
    final AppLocalizations l10n = context.l10n;
    final int? discount = product.discountPercent;
    final RatingSummary? summary = ref
        .watch(productReviewsProvider(product.id))
        .value
        ?.summary;
    final bool lowStock =
        product.inStock && product.stock <= _lowStockThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (product.category != null)
              Expanded(
                child: Text(
                  product.category!.name.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              )
            else
              const Spacer(),
            RatingChip(
              average: summary?.average ?? 0,
              count: summary?.count ?? 0,
              onTap: () => context.push(
                ReviewsScreen.location(product.id),
                extra: product.name,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space2),
        Text(product.name, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppTokens.space3),
        Row(
          children: <Widget>[
            Expanded(
              child: ProductPrice(
                product,
                priceStyle: theme.textTheme.headlineMedium?.copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
            if (discount != null) ...<Widget>[
              const SizedBox(width: AppTokens.space3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tokens.mint.container,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '-$discount%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tokens.mint.onContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (lowStock || !product.inStock) ...<Widget>[
          const SizedBox(height: AppTokens.space3),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space3,
              vertical: AppTokens.space2,
            ),
            decoration: BoxDecoration(
              color: product.inStock
                  ? tokens.warningContainer
                  : theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              product.inStock
                  ? l10n.lowStockLeft(product.stock)
                  : l10n.outOfStock,
              style: theme.textTheme.labelMedium?.copyWith(
                color: product.inStock
                    ? tokens.onWarningContainer
                    : theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppTokens.space5),
        Text(l10n.description, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTokens.space2),
        Text(product.description, style: theme.textTheme.bodyLarge),
        _ReviewsPreview(product),
      ],
    );
  }
}

/// Up to two recent reviews inline, with the door to all of them. Absent
/// entirely while reviews are still loading or when there are none.
class _ReviewsPreview extends ConsumerWidget {
  const _ReviewsPreview(this.product);

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final ProductReviews? reviews = ref
        .watch(productReviewsProvider(product.id))
        .value;
    if (reviews == null || reviews.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppTokens.space6),
        Text(l10n.reviews, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTokens.space3),
        for (final Review review in reviews.items.take(2)) ...<Widget>[
          _ReviewPreviewCard(review),
          const SizedBox(height: AppTokens.space3),
        ],
        TextButton(
          onPressed: () => context.push(
            ReviewsScreen.location(product.id),
            extra: product.name,
          ),
          child: Text(l10n.seeAllReviews),
        ),
      ],
    );
  }
}

class _ReviewPreviewCard extends StatelessWidget {
  const _ReviewPreviewCard(this.review);

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 16,
                backgroundColor: tokens.violet.container,
                child: Text(
                  review.authorName.isEmpty
                      ? '?'
                      : review.authorName[0].toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tokens.violet.onContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(review.authorName, style: theme.textTheme.titleSmall),
                    Text(
                      DateFormatter.date(
                        review.createdAt,
                        context.l10n.localeName,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              RatingStars(review.rating.toDouble(), size: 14),
            ],
          ),
          if (review.comment != null) ...<Widget>[
            const SizedBox(height: AppTokens.space2),
            Text(
              review.comment!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
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

    return Stack(
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
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: AppTokens.space3,
            child: Row(
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
                        : theme.colorScheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
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

    return _FloatingCircleButton(
      tooltip: saved
          ? context.l10n.removeFromFavorites
          : context.l10n.addToFavorites,
      icon: saved ? Icons.favorite : Icons.favorite_outline,
      color: saved
          ? theme.colorScheme.error
          : theme.colorScheme.onSurfaceVariant,
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
      ).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
    }
  }
}

/// Sticky bar: the price on the left, the pill CTA on the right. Adding
/// always puts one unit in; quantities are adjusted in the cart itself.
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
          content: Text(context.l10n.addedToCart),
          action: SnackBarAction(
            label: context.l10n.viewCart,
            // The cart is a shell tab now — jump to it instead of stacking.
            onPressed: () => context.go(CartScreen.path),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool inStock = widget.product.inStock;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space5,
            AppTokens.space3,
            AppTokens.space5,
            AppTokens.space3,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  PriceFormatter.format(
                    widget.product.price,
                    widget.product.currency,
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space4),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: inStock && !_busy ? _add : null,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          inStock
                              ? context.l10n.addToCart
                              : context.l10n.outOfStock,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

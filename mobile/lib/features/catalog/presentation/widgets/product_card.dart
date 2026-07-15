import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../favorites/application/favorites_controller.dart';
import '../../domain/product.dart';
import '../../domain/product_summary.dart';
import '../product_detail_screen.dart';
import 'product_price.dart';

/// One tile of the catalog grid: soft rounded card, discount badge and a
/// frosted favorite heart floating over the imagery.
class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);
    final int? discount = product.discountPercent;
    final BorderRadius radius = BorderRadius.circular(AppTokens.radiusLg);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: radius,
        boxShadow: tokens.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(ProductDetailScreen.location(product.slug)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _ProductThumbnail(product),
                    Positioned(
                      top: AppTokens.space2,
                      right: AppTokens.space2,
                      child: _FavoriteButton(product),
                    ),
                    if (discount != null)
                      Positioned(
                        top: AppTokens.space2,
                        left: AppTokens.space2,
                        child: _DiscountBadge(percent: discount),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTokens.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppTokens.space1),
                    ProductPrice(
                      product,
                      priceStyle: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    if (!product.inStock) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.outOfStock,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final PastelPair mint = AppTokens.of(context).mint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: mint.container,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '-$percent%',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: mint.onContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton(this.product);

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bool saved = ref
        .watch(favoriteProductIdsProvider)
        .contains(product.id);

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        tooltip: saved
            ? context.l10n.removeFromFavorites
            : context.l10n.addToFavorites,
        icon: Icon(
          saved ? Icons.favorite : Icons.favorite_outline,
          color: saved
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: () => _toggle(context, ref),
      ),
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

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail(this.product);

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    if (product.images.isEmpty) return placeholder;
    return Image.network(
      AppConfig.resolveMediaUrl(product.images.first.url),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
      frameBuilder: (_, Widget child, int? frame, bool syncLoaded) {
        if (syncLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );
  }
}

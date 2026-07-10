import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../favorites/application/favorites_controller.dart';
import '../../domain/product.dart';
import '../../domain/product_summary.dart';
import '../product_detail_screen.dart';
import 'product_price.dart';

/// One tile of the catalog grid, with a favorite heart over the thumbnail.
class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
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
                    top: 4,
                    right: 4,
                    child: _FavoriteButton(product),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  ProductPrice(product),
                  if (!product.inStock) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      'Out of stock',
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
      color: theme.colorScheme.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        tooltip: saved ? 'Remove from favorites' : 'Add to favorites',
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
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
    );
  }
}

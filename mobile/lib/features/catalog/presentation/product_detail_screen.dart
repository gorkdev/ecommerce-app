import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.name ?? 'Product')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) => _DetailError(
          error: error,
          onRetry: () => ref.invalidate(productDetailProvider(widget.slug)),
        ),
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
        const SizedBox(height: 24),
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

class _DetailError extends StatelessWidget {
  const _DetailError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool gone =
        error is ApiStatusException && (error as ApiStatusException).isNotFound;
    final String message = gone
        ? 'This product is no longer available.'
        : error is ApiException
        ? (error as ApiException).message
        : 'Something went wrong.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              gone ? Icons.inventory_2_outlined : Icons.wifi_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (!gone) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

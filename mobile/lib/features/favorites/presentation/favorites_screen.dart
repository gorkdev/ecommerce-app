import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/formatting/price_formatter.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/remote_thumbnail.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../catalog/presentation/product_detail_screen.dart';
import '../application/favorites_controller.dart';
import '../domain/favorite.dart';

/// Saved products. Hearts here un-save; tapping a row opens the product.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  static const String path = '/favorites';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Favorite>> favorites = ref.watch(
      favoritesControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.favorites)),
      body: _buildBody(context, ref, favorites),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Favorite>> favorites,
  ) {
    final List<Favorite>? items = favorites.value;
    if (items == null) {
      if (favorites.hasError) {
        return ErrorView(
          error: favorites.error,
          onRetry: () =>
              ref.read(favoritesControllerProvider.notifier).reload(),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return EmptyView(
        icon: Icons.favorite_outline,
        title: context.l10n.nothingSavedYet,
        subtitle: context.l10n.favoritesHint,
      );
    }

    return ListView.separated(
      padding: AppTokens.screenPadding,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space3),
      itemBuilder: (_, int index) => _FavoriteTile(items[index]),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile(this.favorite);

  final Favorite favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final String? warning = !favorite.product.isActive
        ? context.l10n.noLongerAvailable
        : !favorite.product.inStock
        ? context.l10n.outOfStock
        : null;

    return SoftCard(
      padding: const EdgeInsets.all(AppTokens.space3),
      onTap: () =>
          context.push(ProductDetailScreen.location(favorite.product.slug)),
      child: Row(
        children: <Widget>[
          RemoteThumbnail(url: favorite.product.imageUrl, size: 72),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  favorite.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  PriceFormatter.format(
                    favorite.product.price,
                    favorite.product.currency,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                if (warning != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    warning,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.removeFromFavorites,
            icon: Icon(Icons.favorite, color: theme.colorScheme.error),
            onPressed: () => _unfavorite(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _unfavorite(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(favoritesControllerProvider.notifier)
          .toggle(favorite.product);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.errorText(error))),
      );
    }
  }
}

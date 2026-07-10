import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../catalog/domain/product_summary.dart';
import '../data/favorites_repository.dart';
import '../domain/favorite.dart';

/// Owns the favorites list with an optimistic [toggle]: the heart flips
/// instantly, the server call runs behind it, and a failure rolls the list
/// back before rethrowing for the screen to report.
final class FavoritesController extends AsyncNotifier<List<Favorite>> {
  /// Product ids with a toggle round-trip in flight. A second tap while the
  /// first is pending is dropped: letting it through would race an add
  /// against a remove on the server.
  final Set<String> _pending = <String>{};

  @override
  Future<List<Favorite>> build() {
    return ref.read(favoritesRepositoryProvider).list();
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<Favorite>>();
    state = await AsyncValue.guard<List<Favorite>>(
      () => ref.read(favoritesRepositoryProvider).list(),
    );
  }

  Future<void> toggle(ProductSummary product) async {
    if (_pending.contains(product.id)) return;

    final List<Favorite> before = state.value ?? const <Favorite>[];
    final bool isFavorite = before.any(
      (Favorite favorite) => favorite.productId == product.id,
    );

    _pending.add(product.id);
    state = AsyncData<List<Favorite>>(
      isFavorite
          ? before
                .where((Favorite favorite) => favorite.productId != product.id)
                .toList()
          : <Favorite>[Favorite.local(product), ...before],
    );

    try {
      final FavoritesRepository repository = ref.read(
        favoritesRepositoryProvider,
      );
      if (isFavorite) {
        await repository.remove(product.id);
      } else {
        // The server returns the authoritative list; it replaces the
        // optimistic stand-in entry.
        final List<Favorite> fresh = await repository.add(product.id);
        if (ref.mounted) state = AsyncData<List<Favorite>>(fresh);
      }
    } on ApiException {
      if (ref.mounted) state = AsyncData<List<Favorite>>(before);
      rethrow;
    } finally {
      _pending.remove(product.id);
    }
  }
}

final AsyncNotifierProvider<FavoritesController, List<Favorite>>
favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, List<Favorite>>(
      FavoritesController.new,
    );

/// The saved product ids, for cheap `contains` checks on hearts everywhere.
final Provider<Set<String>> favoriteProductIdsProvider = Provider<Set<String>>(
  (ref) =>
      ref
          .watch(favoritesControllerProvider)
          .value
          ?.map((Favorite favorite) => favorite.productId)
          .toSet() ??
      const <String>{},
);

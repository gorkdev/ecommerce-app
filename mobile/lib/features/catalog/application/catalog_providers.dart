import 'package:flutter_riverpod/flutter_riverpod.dart';
// The family types live in the `misc` library, not the main export.
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../data/catalog_repository.dart';
import '../domain/category.dart';
import '../domain/product.dart';

/// The category forest, cached for the whole session — it changes rarely and
/// the chips row wants it on every catalog visit.
final FutureProvider<List<Category>> categoriesProvider =
    FutureProvider<List<Category>>(
      (ref) => ref.watch(catalogRepositoryProvider).fetchCategories(),
    );

/// One product's detail by slug. Auto-disposed: leaving the screen drops the
/// cache, so coming back always shows fresh stock and pricing.
final FutureProviderFamily<Product, String> productDetailProvider =
    FutureProvider.autoDispose.family<Product, String>(
      (ref, slug) => ref.watch(catalogRepositoryProvider).fetchProduct(slug),
    );

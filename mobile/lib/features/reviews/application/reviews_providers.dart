import 'package:flutter_riverpod/flutter_riverpod.dart';
// The family types live in the `misc` library, not the main export.
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../data/reviews_repository.dart';
import '../domain/review.dart';

/// A product's reviews and rating summary. Auto-disposed so every visit
/// shows fresh numbers; submitting invalidates it explicitly.
final FutureProviderFamily<ProductReviews, String> productReviewsProvider =
    FutureProvider.autoDispose.family<ProductReviews, String>(
      (ref, productId) =>
          ref.watch(reviewsRepositoryProvider).fetchForProduct(productId),
    );

/// The caller's own review for a product (null when none) — decides whether
/// the CTA reads "write" or "edit".
final FutureProviderFamily<Review?, String> myReviewProvider =
    FutureProvider.autoDispose.family<Review?, String>(
      (ref, productId) =>
          ref.watch(reviewsRepositoryProvider).fetchOwn(productId),
    );

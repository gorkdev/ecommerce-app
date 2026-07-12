import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/formatting/date_formatter.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/reviews_providers.dart';
import '../data/reviews_repository.dart';
import '../domain/review.dart';
import 'widgets/rating_stars.dart';

/// A product's reviews: the server-computed summary up top, the caller's own
/// write/edit affordance, then everyone's words.
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({required this.productId, this.productName, super.key});

  final String productId;
  final String? productName;

  static const String path = '/reviews/:productId';

  static String location(String productId) => '/reviews/$productId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProductReviews> reviewsState = ref.watch(
      productReviewsProvider(productId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(productName ?? context.l10n.reviews)),
      body: _buildBody(context, ref, reviewsState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ProductReviews> reviewsState,
  ) {
    final ProductReviews? reviews = reviewsState.value;
    if (reviews == null) {
      if (reviewsState.hasError) {
        return ErrorView(
          error: reviewsState.error,
          onRetry: () => ref.invalidate(productReviewsProvider(productId)),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (reviews.summary.count > 0) ...<Widget>[
          _SummaryHeader(reviews.summary),
          const SizedBox(height: 16),
        ],
        _OwnReviewCta(productId),
        const Divider(height: 32),
        if (reviews.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.rate_review_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.noReviewsYet,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.beFirstToReview,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          for (final Review review in reviews.items) _ReviewTile(review),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader(this.summary);

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          children: <Widget>[
            Text(
              summary.average.toStringAsFixed(1),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            RatingStars(summary.average),
            const SizedBox(height: 4),
            Text(
              context.l10n.nReviews(summary.count),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: <Widget>[
              for (int stars = 5; stars >= 1; stars--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: <Widget>[
                      Text('$stars', style: theme.textTheme.labelSmall),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: summary.count == 0
                                ? 0
                                : summary.countFor(stars) / summary.count,
                            minHeight: 6,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '${summary.countFor(stars)}',
                          style: theme.textTheme.labelSmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Write a review" / "Edit your review", depending on whether one exists.
class _OwnReviewCta extends ConsumerWidget {
  const _OwnReviewCta(this.productId);

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Review? own = ref.watch(myReviewProvider(productId)).value;

    return OutlinedButton.icon(
      icon: Icon(own == null ? Icons.rate_review_outlined : Icons.edit),
      label: Text(
        own == null ? context.l10n.writeReview : context.l10n.editYourReview,
      ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ReviewFormSheet(productId: productId, existing: own),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile(this.review);

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? comment = review.comment;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  review.authorName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                DateFormatter.date(review.createdAt, context.l10n.localeName),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          RatingStars(review.rating.toDouble(), size: 14),
          if (comment != null && comment.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              comment,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// The write/edit sheet. Submitting upserts server-side; deleting removes
/// the caller's review. Both refresh the list and the CTA on the way out.
class _ReviewFormSheet extends ConsumerStatefulWidget {
  const _ReviewFormSheet({required this.productId, required this.existing});

  final String productId;
  final Review? existing;

  @override
  ConsumerState<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends ConsumerState<_ReviewFormSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final TextEditingController _comment = TextEditingController(
    text: widget.existing?.comment,
  );
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Padding(
      // Keep the sheet above the keyboard.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.existing == null ? l10n.writeReview : l10n.editYourReview,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Center(
            child: RatingInput(
              value: _rating,
              onChanged: (int stars) => setState(() => _rating = stars),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 4,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.commentOptional,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _rating == 0 || _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.submitReview),
          ),
          if (widget.existing != null)
            TextButton(
              onPressed: _busy ? null : _delete,
              child: Text(
                l10n.deleteMyReview,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final String comment = _comment.text.trim();
    await _run(
      () => ref
          .read(reviewsRepositoryProvider)
          .submit(
            widget.productId,
            rating: _rating,
            comment: comment.isEmpty ? null : comment,
          ),
    );
  }

  Future<void> _delete() async {
    await _run(
      () => ref.read(reviewsRepositoryProvider).removeOwn(widget.productId),
    );
  }

  Future<void> _run(Future<void> Function() act) async {
    setState(() => _busy = true);
    try {
      await act();
      if (!mounted) return;
      ref.invalidate(productReviewsProvider(widget.productId));
      ref.invalidate(myReviewProvider(widget.productId));
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorText(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

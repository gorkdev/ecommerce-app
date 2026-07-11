/// One customer review, as the public endpoint exposes it (author display
/// name only — never an email).
final class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.authorId,
    required this.authorName,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? user = json['user'] as Map<String, dynamic>?;
    return Review(
      id: json['id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      authorId: user?['id'] as String? ?? (json['userId'] as String),
      authorName: user?['name'] as String? ?? 'Customer',
    );
  }

  final String id;

  /// 1..5 whole stars.
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String authorId;
  final String authorName;
}

/// The server-computed rating aggregate — the client never averages ratings
/// itself.
final class RatingSummary {
  const RatingSummary({
    required this.average,
    required this.count,
    required this.distribution,
  });

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    // JSON object keys are strings; the API's map is keyed 1..5.
    final Map<String, dynamic> raw =
        json['distribution'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return RatingSummary(
      average: (json['average'] as num).toDouble(),
      count: json['count'] as int,
      distribution: <int, int>{
        for (final MapEntry<String, dynamic> entry in raw.entries)
          int.parse(entry.key): entry.value as int,
      },
    );
  }

  /// Already rounded to one decimal by the server; 0 when there are none.
  final double average;
  final int count;
  final Map<int, int> distribution;

  int countFor(int stars) => distribution[stars] ?? 0;
}

/// What `GET /products/:id/reviews` returns: the reviews plus their summary.
final class ProductReviews {
  const ProductReviews({required this.items, required this.summary});

  factory ProductReviews.fromJson(Map<String, dynamic> json) => ProductReviews(
    items: (json['items'] as List<dynamic>)
        .map((item) => Review.fromJson(item as Map<String, dynamic>))
        .toList(),
    summary: RatingSummary.fromJson(json['summary'] as Map<String, dynamic>),
  );

  final List<Review> items;
  final RatingSummary summary;
}

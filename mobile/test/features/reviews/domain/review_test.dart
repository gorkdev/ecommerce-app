import 'package:ecommerce_app/features/reviews/domain/review.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, Object?> _payload = <String, Object?>{
  'items': <Object?>[
    <String, Object?>{
      'id': 'rev_1',
      'productId': 'prd_1',
      'userId': 'usr_1',
      'rating': 4,
      'comment': 'Solid build.',
      'createdAt': '2026-07-11T09:30:00.000Z',
      'user': <String, Object?>{'id': 'usr_1', 'name': 'Ada'},
    },
    <String, Object?>{
      'id': 'rev_2',
      'productId': 'prd_1',
      'userId': 'usr_2',
      'rating': 5,
      'comment': null,
      'createdAt': '2026-07-10T09:30:00.000Z',
      'user': <String, Object?>{'id': 'usr_2', 'name': 'Grace'},
    },
  ],
  'summary': <String, Object?>{
    'average': 4.5,
    'count': 2,
    // JSON object keys arrive as strings.
    'distribution': <String, Object?>{'1': 0, '2': 0, '3': 0, '4': 1, '5': 1},
  },
};

void main() {
  test('ProductReviews.fromJson parses items and the summary', () {
    final ProductReviews reviews = ProductReviews.fromJson(
      Map<String, dynamic>.from(_payload),
    );

    expect(reviews.items, hasLength(2));
    expect(reviews.items.first.authorName, 'Ada');
    expect(reviews.items.first.rating, 4);
    expect(reviews.items.first.comment, 'Solid build.');
    expect(reviews.items[1].comment, isNull);
    expect(reviews.summary.average, 4.5);
    expect(reviews.summary.count, 2);
    expect(reviews.summary.countFor(5), 1);
    expect(reviews.summary.countFor(3), 0);
  });

  test('an integer average still parses as a double', () {
    final RatingSummary summary = RatingSummary.fromJson(
      const <String, dynamic>{
        'average': 0,
        'count': 0,
        'distribution': <String, Object?>{},
      },
    );

    expect(summary.average, 0.0);
    expect(summary.countFor(4), 0);
  });

  test('a review without the user embed falls back gracefully', () {
    final Review review = Review.fromJson(const <String, dynamic>{
      'id': 'rev_1',
      'productId': 'prd_1',
      'userId': 'usr_1',
      'rating': 3,
      'comment': null,
      'createdAt': '2026-07-11T09:30:00.000Z',
    });

    expect(review.authorId, 'usr_1');
    expect(review.authorName, 'Customer');
  });
}

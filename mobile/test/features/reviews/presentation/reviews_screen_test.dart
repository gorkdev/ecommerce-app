import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/reviews/data/reviews_repository.dart';
import 'package:ecommerce_app/features/reviews/domain/review.dart';
import 'package:ecommerce_app/features/reviews/presentation/reviews_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockReviewsRepository extends Mock implements ReviewsRepository {}

// Local timestamps keep the rendered dates machine-independent.
final Review _adasReview = Review(
  id: 'rev_1',
  rating: 4,
  comment: 'Solid build.',
  createdAt: DateTime(2026, 7, 11),
  authorId: 'usr_1',
  authorName: 'Ada',
);

final ProductReviews _twoReviews = ProductReviews(
  items: <Review>[
    _adasReview,
    Review(
      id: 'rev_2',
      rating: 5,
      comment: null,
      createdAt: DateTime(2026, 7, 10),
      authorId: 'usr_2',
      authorName: 'Grace',
    ),
  ],
  summary: const RatingSummary(
    average: 4.5,
    count: 2,
    distribution: <int, int>{1: 0, 2: 0, 3: 0, 4: 1, 5: 1},
  ),
);

const ProductReviews _noReviews = ProductReviews(
  items: <Review>[],
  summary: RatingSummary(
    average: 0,
    count: 0,
    distribution: <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  ),
);

void main() {
  late MockReviewsRepository repository;

  setUp(() {
    repository = MockReviewsRepository();
    when(() => repository.fetchOwn(any())).thenAnswer((_) async => null);
  });

  Future<void> pumpReviews(WidgetTester tester) async {
    // Portrait, like a real phone.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry stays off in tests.
        retry: (int retryCount, Object error) => null,
        overrides: [reviewsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: ReviewsScreen(
            productId: 'prd_1',
            productName: 'Wireless Headphones',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the summary and every review', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchForProduct('prd_1'),
    ).thenAnswer((_) async => _twoReviews);

    await pumpReviews(tester);

    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('2 reviews'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Solid build.'), findsOneWidget);
    expect(find.text('Grace'), findsOneWidget);
    expect(find.text('Jul 11, 2026'), findsOneWidget);
    expect(find.text('Write a review'), findsOneWidget);
  });

  testWidgets('an unreviewed product invites the first review', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchForProduct('prd_1'),
    ).thenAnswer((_) async => _noReviews);

    await pumpReviews(tester);

    expect(find.text('No reviews yet'), findsOneWidget);
    expect(
      find.text('Purchased this product? Be the first to review it.'),
      findsOneWidget,
    );
  });

  testWidgets('submitting needs a rating first', (WidgetTester tester) async {
    when(
      () => repository.fetchForProduct('prd_1'),
    ).thenAnswer((_) async => _noReviews);

    await pumpReviews(tester);
    await tester.tap(find.text('Write a review'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Submit review'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('the write flow submits the picked stars and trimmed comment', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchForProduct('prd_1'),
    ).thenAnswer((_) async => _noReviews);
    when(
      () => repository.submit(
        any(),
        rating: any(named: 'rating'),
        comment: any(named: 'comment'),
      ),
    ).thenAnswer((_) async => _adasReview);

    await pumpReviews(tester);
    await tester.tap(find.text('Write a review'));
    await tester.pumpAndSettle();

    // The empty list leaves the sheet's own five input stars as the only
    // star icons on screen; the fourth one means "4 stars".
    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Nice!  ');
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    verify(
      () => repository.submit('prd_1', rating: 4, comment: 'Nice!'),
    ).called(1);
    // The sheet closed and the list refreshed.
    expect(find.text('Submit review'), findsNothing);
    verify(() => repository.fetchForProduct('prd_1')).called(2);
  });

  testWidgets('the purchase gate keeps the sheet open with the reason', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchForProduct('prd_1'),
    ).thenAnswer((_) async => _noReviews);
    when(
      () => repository.submit(
        any(),
        rating: any(named: 'rating'),
        comment: any(named: 'comment'),
      ),
    ).thenThrow(
      const ApiStatusException(
        403,
        'You can only review products you have purchased',
      ),
    );

    await pumpReviews(tester);
    await tester.tap(find.text('Write a review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(
      find.text('You can only review products you have purchased'),
      findsOneWidget,
    );
    expect(find.text('Submit review'), findsOneWidget);
  });

  testWidgets('an existing review switches the flow to editing', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.fetchForProduct('prd_1'),
    ).thenAnswer((_) async => _twoReviews);
    when(
      () => repository.fetchOwn('prd_1'),
    ).thenAnswer((_) async => _adasReview);
    when(() => repository.removeOwn('prd_1')).thenAnswer((_) async {});

    await pumpReviews(tester);

    expect(find.text('Write a review'), findsNothing);
    await tester.tap(find.text('Edit your review'));
    await tester.pumpAndSettle();

    // Prefilled with the existing comment, and deletable.
    expect(
      find.descendant(
        of: find.byType(TextField),
        matching: find.text('Solid build.'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Delete my review'));
    await tester.pumpAndSettle();

    verify(() => repository.removeOwn('prd_1')).called(1);
    expect(find.text('Delete my review'), findsNothing);
  });
}

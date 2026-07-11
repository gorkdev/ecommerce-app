import 'package:dio/dio.dart';
import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/reviews/data/reviews_repository.dart';
import 'package:ecommerce_app/features/reviews/domain/review.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_adapter.dart';

const Map<String, Object?> _reviewJson = <String, Object?>{
  'id': 'rev_1',
  'productId': 'prd_1',
  'userId': 'usr_1',
  'rating': 4,
  'comment': 'Solid build.',
  'createdAt': '2026-07-11T09:30:00.000Z',
  'user': <String, Object?>{'id': 'usr_1', 'name': 'Ada'},
};

const Map<String, Object?> _listJson = <String, Object?>{
  'items': <Object?>[_reviewJson],
  'summary': <String, Object?>{
    'average': 4.0,
    'count': 1,
    'distribution': <String, Object?>{'1': 0, '2': 0, '3': 0, '4': 1, '5': 0},
  },
};

({ReviewsRepository repository, FakeHttpAdapter adapter}) _build(
  FakeResponder responder,
) {
  final FakeHttpAdapter adapter = FakeHttpAdapter(responder);
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test',
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = adapter;
  return (repository: ReviewsRepository(dio), adapter: adapter);
}

void main() {
  test('fetchForProduct GETs the public list and parses it', () async {
    final sut = _build((_) => FakeHttpAdapter.json(200, _listJson));

    final ProductReviews reviews = await sut.repository.fetchForProduct(
      'prd_1',
    );

    expect(sut.adapter.requests.single.path, '/products/prd_1/reviews');
    expect(sut.adapter.requests.single.method, 'GET');
    expect(reviews.items.single.authorName, 'Ada');
    expect(reviews.summary.count, 1);
  });

  test('fetchOwn returns the review when one exists', () async {
    final sut = _build((_) => FakeHttpAdapter.json(200, _reviewJson));

    final Review? own = await sut.repository.fetchOwn('prd_1');

    expect(sut.adapter.requests.single.path, '/products/prd_1/reviews/me');
    expect(own?.rating, 4);
  });

  test('fetchOwn maps the empty 200 body to null', () async {
    // Nest serializes a null return as an empty body, not the string "null".
    final sut = _build(
      (_) => ResponseBody.fromString(
        '',
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      ),
    );

    expect(await sut.repository.fetchOwn('prd_1'), isNull);
  });

  test('submit POSTs the rating and skips an absent comment', () async {
    final sut = _build((_) => FakeHttpAdapter.json(201, _reviewJson));

    await sut.repository.submit('prd_1', rating: 4);

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/products/prd_1/reviews');
    expect(request.method, 'POST');
    expect(request.data, <String, Object>{'rating': 4});
  });

  test('submit carries the comment when present', () async {
    final sut = _build((_) => FakeHttpAdapter.json(201, _reviewJson));

    await sut.repository.submit('prd_1', rating: 4, comment: 'Solid build.');

    expect(sut.adapter.requests.single.data, <String, Object>{
      'rating': 4,
      'comment': 'Solid build.',
    });
  });

  test('surfaces the purchase-gate 403 verbatim', () async {
    final sut = _build(
      (_) => FakeHttpAdapter.json(403, <String, Object?>{
        'statusCode': 403,
        'message': 'You can only review products you have purchased',
        'error': 'Forbidden',
      }),
    );

    await expectLater(
      sut.repository.submit('prd_1', rating: 5),
      throwsA(
        isA<ApiStatusException>().having(
          (ApiStatusException e) => e.message,
          'message',
          'You can only review products you have purchased',
        ),
      ),
    );
  });

  test('removeOwn DELETEs the caller review', () async {
    final sut = _build((_) => FakeHttpAdapter.noContent());

    await sut.repository.removeOwn('prd_1');

    expect(sut.adapter.requests.single.path, '/products/prd_1/reviews/me');
    expect(sut.adapter.requests.single.method, 'DELETE');
  });
}

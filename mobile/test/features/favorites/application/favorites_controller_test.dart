import 'dart:async';

import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/catalog/domain/product_summary.dart';
import 'package:ecommerce_app/features/favorites/application/favorites_controller.dart';
import 'package:ecommerce_app/features/favorites/data/favorites_repository.dart';
import 'package:ecommerce_app/features/favorites/domain/favorite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

const ProductSummary _mug = ProductSummary(
  id: 'prd_1',
  slug: 'ceramic-mug',
  name: 'Ceramic Mug',
  price: '49.90',
  currency: 'TRY',
  stock: 10,
  isActive: true,
  imageUrl: null,
);

const Favorite _savedMug = Favorite(
  id: 'fav_1',
  productId: 'prd_1',
  product: _mug,
);

void main() {
  late MockFavoritesRepository repository;

  setUp(() => repository = MockFavoritesRepository());

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [favoritesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads the list on build and exposes the id set', () async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Favorite>[_savedMug]);

    final ProviderContainer container = makeContainer();
    await container.read(favoritesControllerProvider.future);

    expect(container.read(favoriteProductIdsProvider), <String>{'prd_1'});
  });

  test('toggle adds optimistically, then applies the server list', () async {
    when(() => repository.list()).thenAnswer((_) async => const <Favorite>[]);
    final Completer<List<Favorite>> pending = Completer<List<Favorite>>();
    when(() => repository.add('prd_1')).thenAnswer((_) => pending.future);

    final ProviderContainer container = makeContainer();
    final FavoritesController controller = container.read(
      favoritesControllerProvider.notifier,
    );
    await container.read(favoritesControllerProvider.future);

    final Future<void> toggling = controller.toggle(_mug);

    // The heart flips before the server answers.
    expect(container.read(favoriteProductIdsProvider), <String>{'prd_1'});

    pending.complete(const <Favorite>[_savedMug]);
    await toggling;

    expect(
      container.read(favoritesControllerProvider).value!.single.id,
      'fav_1', // the optimistic stand-in was replaced by the real entry
    );
  });

  test('toggle removes optimistically and confirms server-side', () async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Favorite>[_savedMug]);
    when(() => repository.remove('prd_1')).thenAnswer((_) async {});

    final ProviderContainer container = makeContainer();
    final FavoritesController controller = container.read(
      favoritesControllerProvider.notifier,
    );
    await container.read(favoritesControllerProvider.future);

    await controller.toggle(_mug);

    verify(() => repository.remove('prd_1')).called(1);
    expect(container.read(favoriteProductIdsProvider), isEmpty);
  });

  test('a failed toggle rolls the list back and rethrows', () async {
    when(() => repository.list()).thenAnswer((_) async => const <Favorite>[]);
    when(() => repository.add('prd_1')).thenThrow(const NetworkException());

    final ProviderContainer container = makeContainer();
    final FavoritesController controller = container.read(
      favoritesControllerProvider.notifier,
    );
    await container.read(favoritesControllerProvider.future);

    await expectLater(
      controller.toggle(_mug),
      throwsA(isA<NetworkException>()),
    );

    expect(container.read(favoriteProductIdsProvider), isEmpty);
    expect(container.read(favoritesControllerProvider).hasError, isFalse);
  });

  test('a second tap while the first is in flight is dropped', () async {
    when(() => repository.list()).thenAnswer((_) async => const <Favorite>[]);
    final Completer<List<Favorite>> pending = Completer<List<Favorite>>();
    when(() => repository.add('prd_1')).thenAnswer((_) => pending.future);

    final ProviderContainer container = makeContainer();
    final FavoritesController controller = container.read(
      favoritesControllerProvider.notifier,
    );
    await container.read(favoritesControllerProvider.future);

    final Future<void> first = controller.toggle(_mug);
    // Looks like an un-favorite (the optimistic add already landed), but it
    // must be ignored: racing a remove against the in-flight add would leave
    // the server and the client disagreeing.
    await controller.toggle(_mug);

    pending.complete(const <Favorite>[_savedMug]);
    await first;

    verify(() => repository.add('prd_1')).called(1);
    verifyNever(() => repository.remove(any()));
    expect(container.read(favoriteProductIdsProvider), <String>{'prd_1'});
  });
}

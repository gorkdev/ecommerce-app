import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/addresses/application/addresses_controller.dart';
import 'package:ecommerce_app/features/addresses/data/addresses_repository.dart';
import 'package:ecommerce_app/features/addresses/domain/address.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAddressesRepository extends Mock implements AddressesRepository {}

const Address _home = Address(
  id: 'adr_1',
  fullName: 'Ada Lovelace',
  phone: '+905551112233',
  line1: 'Analytical Engine St. 42',
  line2: null,
  city: 'Istanbul',
  district: 'Kadikoy',
  postalCode: '34710',
  country: 'TR',
  isDefault: true,
);

const Address _work = Address(
  id: 'adr_2',
  fullName: 'Ada Lovelace',
  phone: '+905551112233',
  line1: 'Office Park 7',
  line2: null,
  city: 'Ankara',
  district: 'Cankaya',
  postalCode: '06690',
  country: 'TR',
  isDefault: false,
);

const AddressInput _input = AddressInput(
  fullName: 'Ada Lovelace',
  phone: '+905551112233',
  line1: 'Analytical Engine St. 42',
  line2: null,
  city: 'Istanbul',
  district: 'Kadikoy',
  postalCode: '34710',
  country: 'TR',
);

void main() {
  late MockAddressesRepository repository;

  setUp(() {
    repository = MockAddressesRepository();
    registerFallbackValue(_input);
  });

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [addressesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads the book on build and exposes the default', () async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Address>[_home, _work]);

    final ProviderContainer container = makeContainer();
    final List<Address> addresses = await container.read(
      addressesControllerProvider.future,
    );

    expect(addresses, hasLength(2));
    expect(container.read(defaultAddressProvider)?.id, 'adr_1');
  });

  test('save creates and then refetches the list', () async {
    when(() => repository.list()).thenAnswer((_) async => const <Address>[]);
    when(() => repository.create(any())).thenAnswer((_) async => _home);

    final ProviderContainer container = makeContainer();
    await container.read(addressesControllerProvider.future);
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Address>[_home]);

    await container
        .read(addressesControllerProvider.notifier)
        .save(input: _input);

    verify(() => repository.create(_input)).called(1);
    verifyNever(() => repository.update(any(), any()));
    expect(
      container.read(addressesControllerProvider).value,
      const <Address>[_home],
    );
  });

  test('save with an id updates instead', () async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Address>[_home]);
    when(
      () => repository.update(any(), any()),
    ).thenAnswer((_) async => _home);

    final ProviderContainer container = makeContainer();
    await container.read(addressesControllerProvider.future);

    await container
        .read(addressesControllerProvider.notifier)
        .save(id: 'adr_1', input: _input);

    verify(() => repository.update('adr_1', _input)).called(1);
    verifyNever(() => repository.create(any()));
  });

  test('setDefault and remove pass through and refetch', () async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Address>[_home, _work]);
    when(() => repository.setDefault(any())).thenAnswer((_) async => _work);
    when(() => repository.remove(any())).thenAnswer((_) async {});

    final ProviderContainer container = makeContainer();
    await container.read(addressesControllerProvider.future);

    await container
        .read(addressesControllerProvider.notifier)
        .setDefault('adr_2');
    await container.read(addressesControllerProvider.notifier).remove('adr_1');

    verify(() => repository.setDefault('adr_2')).called(1);
    verify(() => repository.remove('adr_1')).called(1);
    // Build + one refetch per mutation.
    verify(() => repository.list()).called(3);
  });

  test('a failed mutation keeps the last good list and rethrows', () async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Address>[_home]);
    when(() => repository.remove(any())).thenThrow(
      const ApiStatusException(
        409,
        'Cannot delete an address already used by orders',
      ),
    );

    final ProviderContainer container = makeContainer();
    await container.read(addressesControllerProvider.future);

    await expectLater(
      container.read(addressesControllerProvider.notifier).remove('adr_1'),
      throwsA(isA<ApiStatusException>()),
    );

    final AsyncValue<List<Address>> state = container.read(
      addressesControllerProvider,
    );
    expect(state.hasError, isFalse);
    expect(state.value, const <Address>[_home]);
    // No refetch after the failed call.
    verify(() => repository.list()).called(1);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/addresses_repository.dart';
import '../domain/address.dart';

/// Owns the address book. Mutations go through the REST endpoints and then
/// refetch the list: ordering and the single-default invariant are decided
/// server-side, so the fresh list is the only trustworthy shape.
///
/// Mutations do not flip the state to loading; failures propagate as
/// `ApiException` for snackbars, leaving the last good list in place.
final class AddressesController extends AsyncNotifier<List<Address>> {
  int _operation = 0;

  @override
  Future<List<Address>> build() {
    _operation++;
    return ref.read(addressesRepositoryProvider).list();
  }

  /// Creates ([id] null) or fully updates an existing address.
  Future<void> save({String? id, required AddressInput input}) =>
      _mutate((AddressesRepository repository) async {
        if (id == null) {
          await repository.create(input);
        } else {
          await repository.update(id, input);
        }
      });

  Future<void> setDefault(String id) => _mutate(
    (AddressesRepository repository) => repository.setDefault(id),
  );

  Future<void> remove(String id) =>
      _mutate((AddressesRepository repository) => repository.remove(id));

  Future<void> reload() async {
    final int operation = ++_operation;
    state = const AsyncLoading<List<Address>>();
    final AsyncValue<List<Address>> next =
        await AsyncValue.guard<List<Address>>(
          () => ref.read(addressesRepositoryProvider).list(),
        );
    if (operation != _operation || !ref.mounted) return;
    state = next;
  }

  Future<void> _mutate(
    Future<void> Function(AddressesRepository) run,
  ) async {
    final int operation = ++_operation;
    final AddressesRepository repository = ref.read(
      addressesRepositoryProvider,
    );
    await run(repository); // ApiException propagates, state untouched.
    final List<Address> fresh = await repository.list();
    if (operation != _operation || !ref.mounted) return;
    state = AsyncData<List<Address>>(fresh);
  }
}

final AsyncNotifierProvider<AddressesController, List<Address>>
addressesControllerProvider =
    AsyncNotifierProvider<AddressesController, List<Address>>(
      AddressesController.new,
    );

/// The default address, or null while loading / when the book is empty.
final Provider<Address?> defaultAddressProvider = Provider<Address?>((ref) {
  final List<Address>? addresses = ref
      .watch(addressesControllerProvider)
      .value;
  if (addresses == null) return null;
  for (final Address address in addresses) {
    if (address.isDefault) return address;
  }
  return null;
});

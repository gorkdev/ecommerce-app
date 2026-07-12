import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/addresses/data/addresses_repository.dart';
import 'package:ecommerce_app/features/addresses/domain/address.dart';
import 'package:ecommerce_app/features/addresses/presentation/addresses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/test_app.dart';

class MockAddressesRepository extends Mock implements AddressesRepository {}

const Address _home = Address(
  id: 'adr_1',
  fullName: 'Ada Lovelace',
  phone: '+905551112233',
  line1: 'Analytical Engine St. 42',
  line2: 'Floor 3',
  city: 'Istanbul',
  district: 'Kadikoy',
  postalCode: '34710',
  country: 'TR',
  isDefault: true,
);

const Address _work = Address(
  id: 'adr_2',
  fullName: 'Ada at Work',
  phone: '+905551112233',
  line1: 'Office Park 7',
  line2: null,
  city: 'Ankara',
  district: 'Cankaya',
  postalCode: '06690',
  country: 'TR',
  isDefault: false,
);

void main() {
  late MockAddressesRepository repository;

  setUp(() => repository = MockAddressesRepository());

  Future<void> pumpAddresses(WidgetTester tester) async {
    // Portrait, like a real phone.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry stays off in tests.
        retry: (int retryCount, Object error) => null,
        overrides: [addressesRepositoryProvider.overrideWithValue(repository)],
        child: testApp(home: const AddressesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenuFor(WidgetTester tester, {int index = 0}) async {
    await tester.tap(find.byIcon(Icons.more_vert).at(index));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the book with the default pinned and badged', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Address>[_home, _work]);

    await pumpAddresses(tester);

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Analytical Engine St. 42, Floor 3'), findsOneWidget);
    expect(find.text('Kadikoy, Istanbul 34710'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Ada at Work'), findsOneWidget);
  });

  testWidgets('shows the empty state with an add affordance', (
    WidgetTester tester,
  ) async {
    when(() => repository.list()).thenAnswer((_) async => const <Address>[]);

    await pumpAddresses(tester);

    expect(find.text('No addresses yet'), findsOneWidget);
    expect(find.text('Add address'), findsOneWidget);
  });

  testWidgets('deleting asks first, then refreshes the list', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Address>[_work]);
    when(() => repository.remove('adr_2')).thenAnswer((_) async {
      when(() => repository.list()).thenAnswer((_) async => const <Address>[]);
    });

    await pumpAddresses(tester);

    await openMenuFor(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this address?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => repository.remove('adr_2')).called(1);
    expect(find.text('No addresses yet'), findsOneWidget);
  });

  testWidgets('a blocked delete keeps the card and shows the reason', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Address>[_home]);
    when(() => repository.remove('adr_1')).thenThrow(
      const ApiStatusException(
        409,
        'Cannot delete an address already used by orders',
      ),
    );

    await pumpAddresses(tester);

    await openMenuFor(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text('Cannot delete an address already used by orders'),
      findsOneWidget,
    );
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('the default address offers no "set as default" action', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Address>[_home]);

    await pumpAddresses(tester);
    await openMenuFor(tester);

    expect(find.text('Set as default'), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('setting another default goes through the repository', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.list(),
    ).thenAnswer((_) async => const <Address>[_home, _work]);
    when(() => repository.setDefault('adr_2')).thenAnswer((_) async => _work);

    await pumpAddresses(tester);

    // The second card belongs to the non-default work address.
    await openMenuFor(tester, index: 1);
    await tester.tap(find.text('Set as default'));
    await tester.pumpAndSettle();

    verify(() => repository.setDefault('adr_2')).called(1);
  });
}

import 'dart:async';

import 'package:ecommerce_app/features/addresses/data/addresses_repository.dart';
import 'package:ecommerce_app/features/addresses/domain/address.dart';
import 'package:ecommerce_app/features/addresses/presentation/address_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAddressesRepository extends Mock implements AddressesRepository {}

// AddressInput is a final class, so mocktail's fallback is a real instance.
const AddressInput _fallbackInput = AddressInput(
  fullName: '',
  phone: '',
  line1: '',
  line2: null,
  city: '',
  district: '',
  postalCode: '',
  country: 'TR',
);

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

void main() {
  late MockAddressesRepository repository;

  setUpAll(() => registerFallbackValue(_fallbackInput));

  setUp(() {
    repository = MockAddressesRepository();
    when(() => repository.list()).thenAnswer((_) async => const <Address>[]);
  });

  /// The form pops itself after a successful save, so it needs a real
  /// GoRouter with a screen underneath to land on.
  Future<GoRouter> pumpForm(WidgetTester tester, {Address? initial}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('underneath')),
        ),
        GoRoute(
          path: AddressFormScreen.path,
          builder: (_, _) => AddressFormScreen(initial: initial),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        // Mirrors main.dart: automatic provider retry stays off in tests.
        retry: (int retryCount, Object error) => null,
        overrides: [addressesRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    unawaited(router.push(AddressFormScreen.path));
    await tester.pumpAndSettle();
    return router;
  }

  Finder field(String label) =>
      find.widgetWithText(TextFormField, label);

  Future<void> fillValid(WidgetTester tester) async {
    await tester.enterText(field('Full name'), '  Ada Lovelace ');
    await tester.enterText(field('Phone'), '+905551112233');
    await tester.enterText(field('Address line'), 'Analytical Engine St. 42');
    await tester.enterText(field('District'), 'Kadikoy');
    await tester.enterText(field('City'), 'Istanbul');
    await tester.enterText(field('Postal code'), '34710');
  }

  testWidgets('client-side validation blocks a bad submission', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);

    await fillValid(tester);
    await tester.enterText(field('Full name'), 'A');
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    expect(find.text('At least 2 characters'), findsOneWidget);
    verifyNever(() => repository.create(any()));
  });

  testWidgets('a valid form creates the address trimmed and pops', (
    WidgetTester tester,
  ) async {
    when(() => repository.create(any())).thenAnswer((_) async => _home);

    await pumpForm(tester);
    await fillValid(tester);

    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    final AddressInput sent =
        verify(() => repository.create(captureAny())).captured.single
            as AddressInput;
    expect(sent.fullName, 'Ada Lovelace'); // trimmed
    expect(sent.line2, isNull); // blank optional line stays null
    expect(sent.country, 'TR');
    expect(sent.isDefault, isFalse);
    verifyNever(() => repository.update(any(), any()));
    // Popped back to the screen underneath.
    expect(find.text('underneath'), findsOneWidget);
  });

  testWidgets('editing prefills, updates by id, and pops', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.update(any(), any()),
    ).thenAnswer((_) async => _home);

    await pumpForm(tester, initial: _home);

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Floor 3'), findsOneWidget);

    await tester.enterText(field('City'), 'Izmir');
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    final List<dynamic> captured = verify(
      () => repository.update(captureAny(), captureAny()),
    ).captured;
    expect(captured.first, 'adr_1');
    final AddressInput sent = captured[1] as AddressInput;
    expect(sent.city, 'Izmir');
    expect(sent.line2, 'Floor 3');
    expect(find.text('underneath'), findsOneWidget);
  });

  testWidgets('the default flag cannot be switched off on the default', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester, initial: _home);

    final SwitchListTile toggle = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(toggle.value, isTrue);
    expect(toggle.onChanged, isNull);
    expect(find.text('This is your default address.'), findsOneWidget);
  });
}

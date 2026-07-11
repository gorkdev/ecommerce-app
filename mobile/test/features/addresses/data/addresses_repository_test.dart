import 'package:dio/dio.dart';
import 'package:ecommerce_app/core/network/api_exception.dart';
import 'package:ecommerce_app/features/addresses/data/addresses_repository.dart';
import 'package:ecommerce_app/features/addresses/domain/address.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_adapter.dart';

const Map<String, Object?> _addressJson = <String, Object?>{
  'id': 'adr_1',
  'userId': 'usr_1',
  'fullName': 'Ada Lovelace',
  'phone': '+905551112233',
  'line1': 'Analytical Engine St. 42',
  'line2': null,
  'city': 'Istanbul',
  'district': 'Kadikoy',
  'postalCode': '34710',
  'country': 'TR',
  'isDefault': true,
};

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

({AddressesRepository repository, FakeHttpAdapter adapter}) _build(
  FakeResponder responder,
) {
  final FakeHttpAdapter adapter = FakeHttpAdapter(responder);
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test',
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = adapter;
  return (repository: AddressesRepository(dio), adapter: adapter);
}

void main() {
  test('list GETs /addresses and parses it', () async {
    final sut = _build(
      (_) => FakeHttpAdapter.json(200, <Object?>[_addressJson]),
    );

    final List<Address> addresses = await sut.repository.list();

    expect(sut.adapter.requests.single.path, '/addresses');
    expect(sut.adapter.requests.single.method, 'GET');
    expect(addresses.single.fullName, 'Ada Lovelace');
  });

  test('create POSTs the payload', () async {
    final sut = _build((_) => FakeHttpAdapter.json(201, _addressJson));

    await sut.repository.create(_input);

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/addresses');
    expect(request.method, 'POST');
    expect(request.data, <String, Object?>{
      'fullName': 'Ada Lovelace',
      'phone': '+905551112233',
      'line1': 'Analytical Engine St. 42',
      'line2': null,
      'city': 'Istanbul',
      'district': 'Kadikoy',
      'postalCode': '34710',
      'country': 'TR',
    });
  });

  test('update PATCHes the address by id', () async {
    final sut = _build((_) => FakeHttpAdapter.json(200, _addressJson));

    await sut.repository.update('adr_1', _input);

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/addresses/adr_1');
    expect(request.method, 'PATCH');
  });

  test('setDefault PATCHes only the flag', () async {
    final sut = _build((_) => FakeHttpAdapter.json(200, _addressJson));

    await sut.repository.setDefault('adr_1');

    final RequestOptions request = sut.adapter.requests.single;
    expect(request.path, '/addresses/adr_1');
    expect(request.data, <String, Object>{'isDefault': true});
  });

  test('remove DELETEs the address', () async {
    final sut = _build((_) => FakeHttpAdapter.noContent());

    await sut.repository.remove('adr_1');

    expect(sut.adapter.requests.single.path, '/addresses/adr_1');
    expect(sut.adapter.requests.single.method, 'DELETE');
  });

  test('surfaces the order-history 409 verbatim', () async {
    final sut = _build(
      (_) => FakeHttpAdapter.json(409, <String, Object?>{
        'statusCode': 409,
        'message': 'Cannot delete an address already used by orders',
        'error': 'Conflict',
      }),
    );

    await expectLater(
      sut.repository.remove('adr_1'),
      throwsA(
        isA<ApiStatusException>().having(
          (ApiStatusException e) => e.message,
          'message',
          'Cannot delete an address already used by orders',
        ),
      ),
    );
  });
}

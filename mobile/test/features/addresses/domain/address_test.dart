import 'package:ecommerce_app/features/addresses/domain/address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Address.fromJson parses the API shape', () {
    final Address address = Address.fromJson(const <String, dynamic>{
      'id': 'adr_1',
      'userId': 'usr_1',
      'fullName': 'Ada Lovelace',
      'phone': '+905551112233',
      'line1': 'Analytical Engine St. 42',
      'line2': 'Floor 3',
      'city': 'Istanbul',
      'district': 'Kadikoy',
      'postalCode': '34710',
      'country': 'TR',
      'isDefault': true,
    });

    expect(address.id, 'adr_1');
    expect(address.line2, 'Floor 3');
    expect(address.isDefault, isTrue);
    expect(address.locality, 'Kadikoy, Istanbul 34710');
  });

  test('AddressInput omits the default flag unless claimed', () {
    const AddressInput input = AddressInput(
      fullName: 'Ada Lovelace',
      phone: '+905551112233',
      line1: 'Analytical Engine St. 42',
      line2: null,
      city: 'Istanbul',
      district: 'Kadikoy',
      postalCode: '34710',
      country: 'TR',
    );

    final Map<String, Object?> json = input.toJson();

    // isDefault: false must stay off the wire — the API rejects stripping
    // the flag, moving it is the only legal direction.
    expect(json.containsKey('isDefault'), isFalse);
    // line2 rides as an explicit null so updates can clear it.
    expect(json.containsKey('line2'), isTrue);
    expect(json['line2'], isNull);
  });

  test('AddressInput carries the default claim', () {
    const AddressInput input = AddressInput(
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

    expect(input.toJson()['isDefault'], isTrue);
    expect(input.toJson()['line2'], 'Floor 3');
  });
}

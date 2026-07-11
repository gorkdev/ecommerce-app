/// A saved delivery address, exactly as `/addresses` returns it.
final class Address {
  const Address({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.line1,
    required this.line2,
    required this.city,
    required this.district,
    required this.postalCode,
    required this.country,
    required this.isDefault,
  });

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    phone: json['phone'] as String,
    line1: json['line1'] as String,
    line2: json['line2'] as String?,
    city: json['city'] as String,
    district: json['district'] as String,
    postalCode: json['postalCode'] as String,
    country: json['country'] as String,
    isDefault: json['isDefault'] as bool,
  );

  final String id;
  final String fullName;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String district;
  final String postalCode;
  final String country;
  final bool isDefault;

  /// `Kadikoy, Istanbul 34710` — the one-line locality summary.
  String get locality => '$district, $city $postalCode';
}

/// What the address form submits — the write-side counterpart of [Address].
final class AddressInput {
  const AddressInput({
    required this.fullName,
    required this.phone,
    required this.line1,
    required this.line2,
    required this.city,
    required this.district,
    required this.postalCode,
    required this.country,
    this.isDefault = false,
  });

  final String fullName;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String district;
  final String postalCode;
  final String country;
  final bool isDefault;

  Map<String, Object?> toJson() => <String, Object?>{
    'fullName': fullName,
    'phone': phone,
    'line1': line1,
    // Always sent: null clears the optional second line on updates, while
    // omitting the key would silently keep the old value.
    'line2': line2,
    'city': city,
    'district': district,
    'postalCode': postalCode,
    'country': country,
    // Only ever sent as true — the flag moves to another address, it is
    // never stripped (the API rejects isDefault: false on the default).
    if (isDefault) 'isDefault': true,
  };
}

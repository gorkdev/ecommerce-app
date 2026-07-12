import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../application/addresses_controller.dart';
import '../domain/address.dart';

/// Create or edit an address. Validation mirrors the API DTO's bounds so a
/// well-formed submission never bounces on a 400.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({this.initial, super.key});

  /// Editing when set, creating when null.
  final Address? initial;

  static const String path = '/addresses/edit';

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _postalCode;
  late final TextEditingController _country;
  late bool _isDefault;
  bool _saving = false;

  bool get _editingDefault => widget.initial?.isDefault ?? false;

  @override
  void initState() {
    super.initState();
    final Address? initial = widget.initial;
    _fullName = TextEditingController(text: initial?.fullName);
    _phone = TextEditingController(text: initial?.phone);
    _line1 = TextEditingController(text: initial?.line1);
    _line2 = TextEditingController(text: initial?.line2);
    _city = TextEditingController(text: initial?.city);
    _district = TextEditingController(text: initial?.district);
    _postalCode = TextEditingController(text: initial?.postalCode);
    _country = TextEditingController(text: initial?.country ?? 'TR');
    _isDefault = initial?.isDefault ?? false;
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _fullName,
      _phone,
      _line1,
      _line2,
      _city,
      _district,
      _postalCode,
      _country,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null ? l10n.newAddress : l10n.editAddress,
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _field(
              _fullName,
              label: l10n.fullName,
              validator: _lengthValidator(2, 100),
              capitalization: TextCapitalization.words,
            ),
            _field(
              _phone,
              label: l10n.phone,
              validator: _lengthValidator(7, 20),
              keyboardType: TextInputType.phone,
            ),
            _field(
              _line1,
              label: l10n.addressLine,
              validator: _lengthValidator(3, 200),
              capitalization: TextCapitalization.sentences,
            ),
            _field(
              _line2,
              label: l10n.addressLine2Optional,
              validator: (String? value) {
                final String text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                return _lengthValidator(1, 200)(text);
              },
              capitalization: TextCapitalization.sentences,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _field(
                    _district,
                    label: l10n.district,
                    validator: _lengthValidator(2, 100),
                    capitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _city,
                    label: l10n.city,
                    validator: _lengthValidator(2, 100),
                    capitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _field(
                    _postalCode,
                    label: l10n.postalCode,
                    validator: _lengthValidator(3, 10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _country,
                    label: l10n.countryIso,
                    validator: (String? value) {
                      final String text = value?.trim() ?? '';
                      if (text.length != 2) return l10n.countryFormatHint;
                      return null;
                    },
                    capitalization: TextCapitalization.characters,
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.useAsDefaultAddress),
              // The default flag only ever moves onto another address; it
              // cannot be switched off here.
              subtitle: _editingDefault
                  ? Text(l10n.thisIsDefaultAddress)
                  : null,
              value: _isDefault,
              onChanged: _editingDefault
                  ? null
                  : (bool value) => setState(() => _isDefault = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.saveAddress),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    required String label,
    required String? Function(String?) validator,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        textCapitalization: capitalization,
        keyboardType: keyboardType,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String? Function(String?) _lengthValidator(int min, int max) {
    return (String? value) {
      final String text = value?.trim() ?? '';
      if (text.length < min) return context.l10n.fieldAtLeast(min);
      if (text.length > max) return context.l10n.fieldAtMost(max);
      return null;
    };
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    final String line2 = _line2.text.trim();
    final AddressInput input = AddressInput(
      fullName: _fullName.text.trim(),
      phone: _phone.text.trim(),
      line1: _line1.text.trim(),
      line2: line2.isEmpty ? null : line2,
      city: _city.text.trim(),
      district: _district.text.trim(),
      postalCode: _postalCode.text.trim(),
      country: _country.text.trim().toUpperCase(),
      isDefault: _isDefault,
    );

    setState(() => _saving = true);
    try {
      await ref
          .read(addressesControllerProvider.notifier)
          .save(id: widget.initial?.id, input: input);
      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorText(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

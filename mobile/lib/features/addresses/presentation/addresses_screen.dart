import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/addresses_controller.dart';
import '../domain/address.dart';
import 'address_form_screen.dart';

enum _AddressAction { edit, setDefault, delete }

/// The address book: the default is pinned on top, every mutation defers to
/// the server (which owns the single-default invariant).
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  static const String path = '/addresses';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Address>> addressesState = ref.watch(
      addressesControllerProvider,
    );
    final List<Address>? addresses = addressesState.value;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.addresses)),
      floatingActionButton: addresses == null || addresses.isEmpty
          ? null
          : FloatingActionButton(
              tooltip: context.l10n.addAddress,
              onPressed: () => context.push(AddressFormScreen.path),
              child: const Icon(Icons.add),
            ),
      body: _buildBody(context, ref, addressesState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Address>> addressesState,
  ) {
    final List<Address>? addresses = addressesState.value;
    if (addresses == null) {
      if (addressesState.hasError) {
        return ErrorView(
          error: addressesState.error,
          onRetry: () =>
              ref.read(addressesControllerProvider.notifier).reload(),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (addresses.isEmpty) {
      return EmptyView(
        icon: Icons.location_on_outlined,
        title: context.l10n.noAddressesYet,
        subtitle: context.l10n.noAddressesHint,
        action: FilledButton.tonal(
          onPressed: () => context.push(AddressFormScreen.path),
          child: Text(context.l10n.addAddress),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: addresses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, int index) => _AddressCard(addresses[index]),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard(this.address);

  final Address address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          address.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (address.isDefault) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            context.l10n.defaultBadge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.line2 == null
                        ? address.line1
                        : '${address.line1}, ${address.line2}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(address.locality, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    address.phone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_AddressAction>(
              onSelected: (_AddressAction action) =>
                  _handle(context, ref, action),
              itemBuilder: (_) => <PopupMenuEntry<_AddressAction>>[
                PopupMenuItem<_AddressAction>(
                  value: _AddressAction.edit,
                  child: Text(context.l10n.edit),
                ),
                if (!address.isDefault)
                  PopupMenuItem<_AddressAction>(
                    value: _AddressAction.setDefault,
                    child: Text(context.l10n.setAsDefault),
                  ),
                PopupMenuItem<_AddressAction>(
                  value: _AddressAction.delete,
                  child: Text(context.l10n.delete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _AddressAction action,
  ) async {
    switch (action) {
      case _AddressAction.edit:
        await context.push(AddressFormScreen.path, extra: address);
      case _AddressAction.setDefault:
        await _run(
          context,
          () =>
              ref.read(addressesControllerProvider.notifier).setDefault(
                address.id,
              ),
        );
      case _AddressAction.delete:
        final AppLocalizations l10n = context.l10n;
        final bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(l10n.deleteAddressTitle),
            content: Text(address.line1),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        await _run(
          context,
          () => ref.read(addressesControllerProvider.notifier).remove(
            address.id,
          ),
        );
    }
  }

  Future<void> _run(BuildContext context, Future<void> Function() act) async {
    try {
      await act();
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.errorText(error))),
      );
    }
  }
}

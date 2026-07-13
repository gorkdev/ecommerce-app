import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../addresses/presentation/addresses_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../notifications/application/push_registrar.dart';
import '../../orders/presentation/orders_screen.dart';

/// The account hub: who is signed in, and the doors to everything personal.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const String path = '/profile';

  /// What the language tile shows for the current choice.
  static String _localeLabel(AppLocalizations l10n, Locale? locale) =>
      switch (locale?.languageCode) {
        'en' => l10n.languageEnglish,
        'tr' => l10n.languageTurkish,
        _ => l10n.systemDefault,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthUser? user = ref.watch(authControllerProvider).value;
    final Locale? locale = ref.watch(localeControllerProvider);
    final theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      // The router only lets signed-in users this far; the null branch is a
      // transient frame during sign-out.
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 28,
                        child: Text(
                          user.name.isEmpty
                              ? '?'
                              : user.name[0].toUpperCase(),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(user.name, style: theme.textTheme.titleLarge),
                            Text(
                              user.email,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(l10n.myOrders),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(OrdersScreen.path),
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: Text(l10n.favorites),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(FavoritesScreen.path),
                ),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(l10n.addresses),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AddressesScreen.path),
                ),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(l10n.language),
                  subtitle: Text(_localeLabel(l10n, locale)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickLanguage(context, ref, locale),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text(
                    l10n.signOut,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () async {
                    // The push token must be deleted while the credentials
                    // still authenticate — so before the sign-out.
                    await ref
                        .read(pushRegistrarProvider.notifier)
                        .unregisterDevice();
                    await ref.read(authControllerProvider.notifier).logout();
                  },
                ),
              ],
            ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    Locale? current,
  ) async {
    final AppLocalizations l10n = context.l10n;
    // A sentinel distinguishes "chose the system default" (empty tag) from
    // "dismissed the sheet" (null): only the latter must change nothing.
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final (String tag, String label) in <(String, String)>[
              ('', l10n.systemDefault),
              ('en', l10n.languageEnglish),
              ('tr', l10n.languageTurkish),
            ])
              ListTile(
                leading: Icon(
                  (current?.languageCode ?? '') == tag
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(label),
                onTap: () => Navigator.of(sheetContext).pop(tag),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref
        .read(localeControllerProvider.notifier)
        .set(picked.isEmpty ? null : Locale(picked));
  }
}

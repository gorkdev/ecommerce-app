import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/soft_card.dart';
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
    final AppTokens tokens = AppTokens.of(context);
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      // The router only lets signed-in users this far; the null branch is a
      // transient frame during sign-out.
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: AppTokens.screenPadding,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: tokens.violet.container,
                      child: Text(
                        user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: tokens.violet.onContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(user.name, style: theme.textTheme.titleLarge),
                          Text(user.email, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space6),
                SoftCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTokens.space2,
                  ),
                  child: Column(
                    children: <Widget>[
                      _ProfileTile(
                        icon: Icons.receipt_long_outlined,
                        pair: tokens.periwinkle,
                        title: l10n.myOrders,
                        // Orders and favorites are shell tabs: jump there.
                        onTap: () => context.go(OrdersScreen.path),
                      ),
                      _ProfileTile(
                        icon: Icons.favorite_outline,
                        pair: tokens.rose,
                        title: l10n.favorites,
                        onTap: () => context.go(FavoritesScreen.path),
                      ),
                      _ProfileTile(
                        icon: Icons.location_on_outlined,
                        pair: tokens.cyan,
                        title: l10n.addresses,
                        onTap: () => context.push(AddressesScreen.path),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space4),
                SoftCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTokens.space2,
                  ),
                  child: _ProfileTile(
                    icon: Icons.language_outlined,
                    pair: tokens.violet,
                    title: l10n.language,
                    subtitle: _localeLabel(l10n, locale),
                    onTap: () => _pickLanguage(context, ref, locale),
                  ),
                ),
                const SizedBox(height: AppTokens.space4),
                SoftCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTokens.space2,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.logout,
                        size: 20,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    title: Text(
                      l10n.signOut,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
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

/// One row of the profile hub: pastel icon circle, title, chevron.
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.pair,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final PastelPair pair;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: pair.container, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: pair.onContainer),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: theme.textTheme.bodySmall),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../addresses/presentation/addresses_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../orders/presentation/orders_screen.dart';

/// The account hub: who is signed in, and the doors to everything personal.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const String path = '/profile';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthUser? user = ref.watch(authControllerProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
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
                  title: const Text('My orders'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(OrdersScreen.path),
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('Favorites'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(FavoritesScreen.path),
                ),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Addresses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AddressesScreen.path),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text(
                    'Sign out',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                ),
              ],
            ),
    );
  }
}

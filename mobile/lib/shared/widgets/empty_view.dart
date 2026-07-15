import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Centered full-body empty state with an optional call to action.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);

    return Center(
      child: Padding(
        padding: AppTokens.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppTokens.space5),
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: AppTokens.space2),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: tokens.inkMuted),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: AppTokens.space5),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_tokens.dart';

/// Centered full-body error state with an optional retry.
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.error,
    this.message,
    this.icon = Icons.wifi_off_outlined,
    this.onRetry,
    super.key,
  });

  final Object? error;

  /// Overrides the message derived from [error].
  final String? message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String text = message ?? context.l10n.errorText(error);

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
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: AppTokens.space5),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppTokens.space5),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(context.l10n.tryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';

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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 16),
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

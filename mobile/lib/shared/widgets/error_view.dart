import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';

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
    final String text =
        message ??
        (error is ApiException
            ? (error! as ApiException).message
            : 'Something went wrong.');

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
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

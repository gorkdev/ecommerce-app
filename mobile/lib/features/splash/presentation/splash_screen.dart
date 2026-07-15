import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/brand_mark.dart';

/// Shown only while the app decides whether a stored session is still valid.
/// The router redirects away as soon as that resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const String path = '/splash';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Spacer(flex: 2),
            const BrandMark(size: 96),
            const SizedBox(height: AppTokens.space5),
            Text(context.l10n.appTitle, style: theme.textTheme.headlineMedium),
            const Spacer(flex: 2),
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: AppTokens.space7),
          ],
        ),
      ),
    );
  }
}

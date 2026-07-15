import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// The one card recipe: surface color, large radius, soft tinted shadow.
/// Screens compose their card content inside this instead of styling ad hoc.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final BorderRadius radius = BorderRadius.circular(AppTokens.radiusLg);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: radius,
        boxShadow: tokens.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTokens.space4),
            child: child,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// The store's visual mark: a rounded primary square with a bag glyph.
/// Used on splash and the auth screens so the brand reads consistently.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(
        Icons.shopping_bag_rounded,
        color: scheme.onPrimary,
        size: size * 0.5,
      ),
    );
  }
}

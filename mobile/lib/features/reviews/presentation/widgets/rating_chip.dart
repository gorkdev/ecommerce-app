import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Amber pastel pill summarizing the rating: ★ 4.6 (12). Tappable when the
/// caller wants it to open the reviews screen.
class RatingChip extends StatelessWidget {
  const RatingChip({
    required this.average,
    required this.count,
    this.onTap,
    super.key,
  });

  final double average;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PastelPair amber = AppTokens.of(context).amber;
    final TextStyle? style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: amber.onContainer,
      fontWeight: FontWeight.w700,
    );

    return Material(
      color: amber.container,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.star_rounded, size: 16, color: amber.onContainer),
              const SizedBox(width: 4),
              Text(average.toStringAsFixed(1), style: style),
              const SizedBox(width: 4),
              Text('($count)', style: style?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Read-only star row for a (possibly fractional) rating value.
class RatingStars extends StatelessWidget {
  const RatingStars(this.value, {this.size = 18, super.key});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.tertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int index) {
        final IconData icon = value >= index + 1
            ? Icons.star
            : value >= index + 0.5
            ? Icons.star_half
            : Icons.star_border;
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}

/// Tappable star row for picking a 1..5 rating.
class RatingInput extends StatelessWidget {
  const RatingInput({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 0 means "nothing picked yet".
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.tertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int index) {
        final int stars = index + 1;
        return IconButton(
          tooltip: '$stars star${stars == 1 ? '' : 's'}',
          icon: Icon(
            stars <= value ? Icons.star : Icons.star_border,
            color: color,
            size: 32,
          ),
          onPressed: () => onChanged(stars),
        );
      }),
    );
  }
}

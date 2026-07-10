import 'package:flutter/material.dart';

import '../../../../shared/formatting/price_formatter.dart';
import '../../domain/product.dart';

/// Current price with the compare-at price struck through next to it, when a
/// genuine discount exists.
class ProductPrice extends StatelessWidget {
  const ProductPrice(this.product, {this.priceStyle, super.key});

  final Product product;
  final TextStyle? priceStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? compareAt = product.compareAtPrice;
    final bool discounted = product.discountPercent != null && compareAt != null;

    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          PriceFormatter.format(product.price, product.currency),
          style:
              priceStyle ??
              theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (discounted)
          Text(
            PriceFormatter.format(compareAt, product.currency),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}

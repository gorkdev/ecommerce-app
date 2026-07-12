import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';

/// What [PriceFilterSheet] pops with. A dismissed sheet pops `null` instead,
/// which callers must treat as "leave the filter alone".
typedef PriceRange = ({double? min, double? max});

/// Bottom sheet with a min/max price pair. Purely local state; the caller
/// applies the result to the product query.
class PriceFilterSheet extends StatefulWidget {
  const PriceFilterSheet({this.initialMin, this.initialMax, super.key});

  final double? initialMin;
  final double? initialMax;

  @override
  State<PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends State<PriceFilterSheet> {
  late final TextEditingController _min;
  late final TextEditingController _max;
  String? _error;

  @override
  void initState() {
    super.initState();
    _min = TextEditingController(text: _initialText(widget.initialMin));
    _max = TextEditingController(text: _initialText(widget.initialMax));
  }

  static String _initialText(double? value) {
    if (value == null) return '';
    // 50.0 reads better as "50" in an input field.
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    final double? min = double.tryParse(_min.text.trim());
    final double? max = double.tryParse(_max.text.trim());
    if (min != null && max != null && min > max) {
      setState(() => _error = context.l10n.minExceedsMax);
      return;
    }
    Navigator.of(context).pop<PriceRange>((min: min, max: max));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Padding(
      // Keeps the fields above the keyboard.
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.priceRange, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _min,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.minLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _max,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.maxLabel),
                ),
              ),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _apply, child: Text(l10n.apply)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop<PriceRange>((min: null, max: null)),
            child: Text(l10n.clearFilter),
          ),
        ],
      ),
    );
  }
}

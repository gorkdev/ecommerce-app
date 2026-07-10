import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

/// Small rounded product thumbnail with a graceful placeholder.
class RemoteThumbnail extends StatelessWidget {
  const RemoteThumbnail({required this.url, this.size = 64, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: size / 2.5,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? placeholder
            : Image.network(
                AppConfig.resolveMediaUrl(url!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

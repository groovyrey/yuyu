import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fade-in network image with a themed placeholder, used across all grids.
class AppImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final double radius;

  const AppImage({
    super.key,
    required this.url,
    this.width = double.infinity,
    this.height = double.infinity,
    this.fit = BoxFit.cover,
    this.radius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: context.appSurfaceVariant,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 24,
          color: context.appOnSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );

    Widget child;
    if (url.isEmpty) {
      child = placeholder;
    } else {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return placeholder;
          },
          errorBuilder: (context, _, __) => placeholder,
        ),
      );
    }

    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

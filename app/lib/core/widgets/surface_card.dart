import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Rounded card with a hairline border and a soft shadow.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.clip = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Clip the content to the rounded corners (for edge-to-edge content).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: p.rule),
        boxShadow: p.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: clip ? AppTheme.cardRadius : BorderRadius.zero,
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small heading used inside cards.
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

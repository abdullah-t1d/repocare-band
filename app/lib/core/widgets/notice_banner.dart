import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Calm amber notice with optional actions (e.g. Reconnect, Dismiss).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    required this.message,
    this.icon = Icons.info_outline,
    this.actions = const [],
    super.key,
  });

  final String message;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: p.noticeBg,
          border: Border.all(color: p.noticeBorder),
          borderRadius: AppTheme.controlRadius,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: p.noticeText),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(message, style: TextStyle(color: p.noticeText, fontSize: 14)),
                ),
              ],
            ),
            if (actions.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ),
      ),
    );
  }
}

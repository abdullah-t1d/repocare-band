import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/motion.dart';
import '../../domain/enums.dart';
import '../../domain/heart_rate_zone.dart';
import '../../domain/live_assessment.dart';
import '../l10n_labels.dart';
import '../providers/live_controller.dart';
import 'beating_heart.dart';

/// The big heart-rate number with its zone, beating heart, glow and hint.
///
/// Colour follows the resting zone and changes smoothly; a weak signal fades
/// the number slightly. A held BPM (see [isHeldHeartRate]) is shown greyed out
/// as the last reading, without zone and without the beating heart.
class HeartRatePanel extends ConsumerWidget {
  const HeartRatePanel({super.key});

  /// Key of the heart-rate number, for tests.
  static const Key bpmKey = ValueKey('live-bpm');

  /// Key of the "last reading" label shown under a held BPM, for tests.
  static const Key heldKey = ValueKey('live-bpm-held');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final live = ref.watch(liveControllerProvider);
    final metrics = live.metrics;
    final bpm = metrics?.bpm;
    final held = metrics != null && isHeldHeartRate(metrics);
    final zone = bpm == null || held ? null : HeartRateZone.forBpm(bpm);

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: held ? p.muted : heartRateColor(bpm, p)),
      duration: context.motion(AppTheme.bodyTransition),
      curve: Curves.easeInOut,
      builder: (context, color, _) {
        final c = color ?? p.muted;
        return DecoratedBox(
          // Soft glow in the zone colour.
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: AlignmentDirectional.topStart,
              radius: 1.3,
              colors: [c.withValues(alpha: zone == null ? 0.0 : 0.16), c.withValues(alpha: 0)],
            ),
          ),
          child: LayoutBuilder(
            // In the wide layout the panel has a fixed height; long hints
            // scroll instead of overflowing.
            builder: (context, constraints) {
              final content = _PanelContent(
                color: c,
                bpm: bpm,
                zone: zone,
                held: held,
                beatCount: live.beatCount,
                quality: metrics == null ? SignalQuality.none : signalQualityOf(metrics),
                hint: metrics == null ? null : liveHintFor(metrics),
              );
              return constraints.hasBoundedHeight ? SingleChildScrollView(child: content) : content;
            },
          ),
        );
      },
    );
  }
}

class _PanelContent extends StatelessWidget {
  const _PanelContent({
    required this.color,
    required this.bpm,
    required this.zone,
    required this.held,
    required this.beatCount,
    required this.quality,
    required this.hint,
  });

  final Color color;
  final double? bpm;
  final HeartRateZone? zone;
  final bool held;
  final int beatCount;
  final SignalQuality quality;
  final LiveHint? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bpm = this.bpm;
    final zone = this.zone;
    final hint = this.hint;
    final switchDuration = context.motion(const Duration(milliseconds: 300));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BeatingHeart(beatCount: beatCount, bpm: bpm, color: color, active: !held),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.heartRate, style: theme.textTheme.labelMedium)),
              AnimatedSwitcher(
                duration: switchDuration,
                child: zone == null
                    ? const SizedBox.shrink()
                    : _ZoneChip(key: ValueKey(zone), label: zone.label(l10n), color: color),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedOpacity(
            opacity: quality.opacity,
            duration: context.motion(AppTheme.bodyTransition),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 10,
              children: [
                Text(
                  bpm == null ? '--' : Fmt.whole(bpm),
                  key: HeartRatePanel.bpmKey,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 92,
                    height: 1,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -2,
                    color: color,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(l10n.unitBpmLong, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: switchDuration,
            child: held
                ? Text(
                    l10n.lastReading,
                    key: HeartRatePanel.heldKey,
                    style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
                  )
                : Text(
                    zone?.caption(l10n) ?? '',
                    key: ValueKey(zone),
                    style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(height: 18),
          if (hint != null) _Hint(hint: hint),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.hint});

  final LiveHint hint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (IconData icon, Color iconColor) = hint.isWarning
        ? (Icons.error_outline, p.warn)
        : hint == LiveHint.stable
            ? (Icons.check_circle_outline, p.ok)
            : (Icons.info_outline, p.muted);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: context.motion(const Duration(milliseconds: 250)),
            child: Text(
              hint.label(context.l10n),
              key: ValueKey(hint),
              style: TextStyle(color: hint.isWarning ? p.warn : p.ink, fontSize: 14, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}

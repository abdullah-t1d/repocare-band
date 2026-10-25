import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/motion.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/enums.dart';
import '../../domain/live_assessment.dart';
import '../l10n_labels.dart';
import '../providers/band_providers.dart';
import '../providers/live_controller.dart';

/// SpO2, HRV, signal quality and chip temperature, side by side on wide
/// screens and two by two on narrow ones.
class MetricTiles extends ConsumerWidget {
  const MetricTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final metrics = ref.watch(liveControllerProvider.select((s) => s.metrics));
    final site = ref.watch(connectionControllerProvider.select((s) => s.site));
    final quality = metrics == null ? SignalQuality.none : signalQualityOf(metrics);
    final onWrist = site == MeasureSite.wrist;

    final tiles = [
      MetricTile(
        title: l10n.spo2Title,
        badge: l10n.estimateBadge,
        value: onWrist ? null : metrics?.spo2,
        unit: '%',
        color: p.oxy,
        note: onWrist ? l10n.spo2WristNote : l10n.spo2Note,
        opacity: quality.opacity,
      ),
      MetricTile(
        title: l10n.hrvTitle,
        value: metrics?.rmssdMs,
        unit: l10n.unitMs,
        note: l10n.hrvNote,
        opacity: quality.opacity,
      ),
      _QualityTile(quality: quality, score: metrics?.contact == true ? metrics!.quality : 0),
      MetricTile(
        title: l10n.chipTempTitle,
        value: metrics?.chipTempC,
        decimals: 1,
        unit: '°C',
        note: l10n.chipTempNote,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 14.0;
        final columns = c.maxWidth >= 860 ? 4 : 2;
        final width = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

/// One reading with title, value, unit and a short note.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.title,
    required this.value,
    this.unit,
    this.decimals = 0,
    this.color,
    this.badge,
    this.note,
    this.opacity = 1,
    super.key,
  });

  final String title;

  /// `null` shows `--`: values the firmware marks as not available are never
  /// shown as numbers.
  final double? value;
  final String? unit;
  final int decimals;
  final Color? color;
  final String? badge;
  final String? note;

  /// Fades the value when the signal is weak.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final v = value;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (badge != null) _Badge(badge!),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedOpacity(
            opacity: v == null ? 1 : opacity,
            duration: context.motion(AppTheme.bodyTransition),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  v == null ? '--' : (decimals == 0 ? Fmt.whole(v) : Fmt.fixed(v, decimals)),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w400,
                    height: 1.15,
                    color: v == null ? p.muted : (color ?? p.ink),
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 6),
                  Text(unit!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 14)),
                ],
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _QualityTile extends StatelessWidget {
  const _QualityTile({required this.quality, required this.score});

  final SignalQuality quality;
  final int score;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final theme = Theme.of(context);
    final duration = context.motion(AppTheme.bodyTransition);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.qualityTitle,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: duration,
            style: TextStyle(
              fontFamily: theme.textTheme.bodyMedium?.fontFamily,
              fontFamilyFallback: theme.textTheme.bodyMedium?.fontFamilyFallback,
              fontSize: 26,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: quality == SignalQuality.none ? p.muted : quality.color(p),
            ),
            child: Text(quality.label(l10n)),
          ),
          const SizedBox(height: 8),
          QualityBar(score: score, color: quality.color(p)),
        ],
      ),
    );
  }
}

/// Thin bar showing a 0–100 quality score.
class QualityBar extends StatelessWidget {
  const QualityBar({required this.score, required this.color, super.key});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: score.clamp(0, 100) / 100),
        duration: context.motion(AppTheme.bodyTransition),
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 6,
          color: color,
          backgroundColor: context.palette.track,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: p.oxy.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: p.oxy, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/band_constants.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/motion.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/enums.dart';
import '../../domain/heart_rate_zone.dart';
import '../../domain/live_assessment.dart';
import '../../domain/measurement/session_result.dart';
import '../l10n_labels.dart';
import '../providers/band_providers.dart';
import '../providers/live_controller.dart';
import '../providers/measure_controller.dart';
import '../widgets/beating_heart.dart';
import '../widgets/metric_tiles.dart';
import 'live_page.dart';

/// Guided measurement: choose finger or wrist, read the instructions, measure
/// with a live progress ring, then see the result and the session history.
class MeasurePage extends ConsumerWidget {
  const MeasurePage({super.key});

  // Keys for tests.
  static const Key fingerKey = ValueKey('measure-finger');
  static const Key wristKey = ValueKey('measure-wrist');
  static const Key startKey = ValueKey('measure-start');
  static const Key cancelKey = ValueKey('measure-cancel');
  static const Key againKey = ValueKey('measure-again');
  static const Key ringKey = ValueKey('measure-ring');
  static const Key liveBpmKey = ValueKey('measure-live-bpm');
  static const Key resultKey = ValueKey('measure-result');
  static const Key resultBpmKey = ValueKey('measure-result-bpm');
  static const Key failureKey = ValueKey('measure-failure');
  static const Key historyKey = ValueKey('measure-history');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final conn = ref.watch(connectionControllerProvider);
    final m = ref.watch(measureControllerProvider);
    final linked = conn.isConnected || conn.isConnecting;
    if (!linked && m.step != MeasureStep.result) {
      return NotConnectedView(
        message: m.stoppedByDisconnect ? l10n.measureDisconnected : l10n.measureNeedsConnection,
      );
    }

    final body = switch (m.step) {
      MeasureStep.choose => const _ModeChoice(),
      MeasureStep.instructions => _Instructions(state: m),
      MeasureStep.measuring => _Measuring(state: m),
      MeasureStep.result => _ResultCard(result: m.result!),
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSwitcher(
                  duration: context.motion(const Duration(milliseconds: 250)),
                  child: KeyedSubtree(key: ValueKey(m.step), child: body),
                ),
                const SizedBox(height: 14),
                _History(history: m.history),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mode choice and instructions

class _ModeChoice extends ConsumerWidget {
  const _ModeChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(measureControllerProvider.notifier);
    final cards = [
      _ModeCard(
        key: MeasurePage.fingerKey,
        site: MeasureSite.finger,
        title: l10n.siteFinger,
        detail: l10n.siteFingerDetail,
        onTap: () => controller.choose(MeasureSite.finger),
      ),
      _ModeCard(
        key: MeasurePage.wristKey,
        site: MeasureSite.wrist,
        title: l10n.siteWrist,
        detail: l10n.siteWristDetail,
        onTap: () => controller.choose(MeasureSite.wrist),
      ),
    ];
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(l10n.measureTitle),
          Text(l10n.measureIntro, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              const gap = 14.0;
              final wide = c.maxWidth >= 520;
              final width = wide ? (c.maxWidth - gap) / 2 : c.maxWidth;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [for (final card in cards) SizedBox(width: width, child: card)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.site,
    required this.title,
    required this.detail,
    required this.onTap,
    super.key,
  });

  final MeasureSite site;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    return Material(
      color: p.paper,
      borderRadius: AppTheme.cardRadius,
      child: InkWell(
        borderRadius: AppTheme.cardRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: p.sheet,
                child: Icon(site.icon, color: p.pulse, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.muted, textDirection: Directionality.of(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Instructions extends ConsumerWidget {
  const _Instructions({required this.state});

  final MeasureState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final theme = Theme.of(context);
    final controller = ref.read(measureControllerProvider.notifier);
    final site = state.site!;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(site.icon, color: p.pulse),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  site == MeasureSite.finger ? l10n.siteFinger : l10n.siteWrist,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(l10n.instructionsTitle, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            site == MeasureSite.finger ? l10n.instructionsFinger : l10n.instructionsWrist,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
          if (state.stoppedByDisconnect) ...[
            const SizedBox(height: 14),
            NoticeBanner(icon: Icons.usb_off, message: l10n.measureDisconnected),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: MeasurePage.startKey,
                onPressed: controller.start,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.startMeasurement),
              ),
              TextButton(onPressed: controller.backToChoice, child: Text(l10n.back)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Measuring

class _Measuring extends ConsumerWidget {
  const _Measuring({required this.state});

  final MeasureState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final theme = Theme.of(context);
    final beatCount = ref.watch(liveControllerProvider.select((s) => s.beatCount));
    final controller = ref.read(measureControllerProvider.notifier);
    final site = state.site!;
    final latest = state.latest;
    final contact = latest?.contact ?? false;
    final held = latest != null && isHeldHeartRate(latest);
    final bpm = contact ? latest?.bpm : null;
    final zone = bpm == null || held ? null : HeartRateZone.forBpm(bpm);
    final color = zone?.color(p) ?? p.muted;
    final quality = latest == null ? SignalQuality.none : signalQualityOf(latest);
    final secondsLeft = (state.remaining.inMilliseconds / 1000).ceil();

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) => _ProgressRing(
              key: MeasurePage.ringKey,
              size: math.min(260, c.maxWidth - 20),
              progress: state.progress,
              color: color,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeatingHeart(beatCount: beatCount, bpm: bpm, color: color, active: zone != null),
                  Text(
                    bpm == null ? '--' : Fmt.whole(bpm),
                    key: MeasurePage.liveBpmKey,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 64,
                      height: 1.05,
                      fontWeight: FontWeight.w300,
                      color: color,
                      fontFeatures: AppTheme.tabularFigures,
                    ),
                  ),
                  Text(l10n.unitBpm, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    held ? l10n.lastReading : zone?.label(l10n) ?? '',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            !contact
                ? (site == MeasureSite.finger ? l10n.waitingFinger : l10n.waitingWrist)
                : l10n.measuringHoldStill,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(l10n.secondsLeft('$secondsLeft'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              const gap = 12.0;
              final width = c.maxWidth >= 480 ? (c.maxWidth - gap) / 2 : c.maxWidth;
              final hrvWaiting = latest != null && isWaitingForHrv(latest);
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: width,
                    child: _Gauge(
                      title: l10n.liveQuality,
                      value: quality.label(l10n),
                      valueColor: quality == SignalQuality.none ? p.muted : quality.color(p),
                      progress: contact ? latest!.quality / 100 : 0,
                      barColor: quality.color(p),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: site == MeasureSite.finger
                        ? _Gauge(
                            title: l10n.hrvTitle,
                            value: hrvWaiting ? l10n.hrvNeedsStillness : '--',
                            valueColor: p.muted,
                            trailing: l10n.hrvSteadyProgress(
                              math.min(state.hrvSteadySeconds, BandConstants.hrvSteadySeconds),
                              BandConstants.hrvSteadySeconds,
                            ),
                            progress: math.min(1, state.hrvSteadySeconds / BandConstants.hrvSteadySeconds),
                            barColor: p.ink,
                          )
                        : _Gauge(
                            title: l10n.stability,
                            value: '${(state.stableProgress * 100).round()}%',
                            valueColor: p.ink,
                            progress: state.stableProgress,
                            barColor: p.ok,
                          ),
                  ),
                ],
              );
            },
          ),
          if (state.firmwareMismatch) ...[
            const SizedBox(height: 14),
            NoticeBanner(
              icon: Icons.memory,
              message: site == MeasureSite.finger ? l10n.firmwareMismatchFinger : l10n.firmwareMismatchWrist,
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: MeasurePage.cancelKey,
            onPressed: controller.cancel,
            icon: const Icon(Icons.stop, size: 18),
            label: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}

/// Large progress ring in the heart-rate zone colour. Progress and colour
/// change smoothly (instantly with reduce motion); the ring fills clockwise in
/// left-to-right layouts and counter-clockwise in right-to-left ones.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.size,
    required this.progress,
    required this.color,
    required this.child,
    super.key,
  });

  final double size;
  final double progress;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final duration = context.motion(const Duration(milliseconds: 400));
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      label: context.l10n.measureProgress,
      value: '${(progress * 100).round()}%',
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: context.motion(AppTheme.bodyTransition),
        builder: (context, animatedColor, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: progress.clamp(0, 1)),
          duration: duration,
          builder: (context, value, _) => CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: value,
              color: animatedColor ?? color,
              track: p.track,
              counterClockwise: rtl,
            ),
            child: SizedBox.square(dimension: size, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.counterClockwise,
  });

  final double progress;
  final Color color;
  final Color track;
  final bool counterClockwise;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.055;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, base);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    final sweep = 2 * math.pi * progress * (counterClockwise ? -1 : 1);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.counterClockwise != counterClockwise;
}

/// Small labelled bar under the ring.
class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.progress,
    required this.barColor,
    this.trailing,
  });

  final String title;
  final String value;
  final Color valueColor;
  final double progress;
  final Color barColor;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: p.paper, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: valueColor)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: QualityBar(score: (progress * 100).round(), color: barColor)),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Text(trailing!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result

class _ResultCard extends ConsumerWidget {
  const _ResultCard({required this.result});

  final SessionResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final theme = Theme.of(context);
    final controller = ref.read(measureControllerProvider.notifier);
    final bpm = result.bpm;
    final zone = bpm == null ? null : HeartRateZone.forBpm(bpm);
    final color = zone?.color(p) ?? p.muted;
    final finger = result.site == MeasureSite.finger;

    return SurfaceCard(
      key: MeasurePage.resultKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            l10n.resultTitle,
            trailing: _SiteChip(site: result.site),
          ),
          if (zone == null)
            Row(
              key: MeasurePage.failureKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: p.warn),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.resultFailed,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.5)),
                ),
              ],
            )
          else ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  Fmt.whole(bpm!),
                  key: MeasurePage.resultBpmKey,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 72,
                    height: 1,
                    fontWeight: FontWeight.w300,
                    color: color,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l10n.unitBpmLong, style: theme.textTheme.bodySmall),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Chip(label: zone.label(l10n), color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(zone.caption(l10n),
                style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          Divider(height: 1, color: p.rule),
          const SizedBox(height: 8),
          if (finger)
            _ResultRow(
              label: l10n.resultSpo2,
              value: result.spo2 == null ? '--' : '${Fmt.whole(result.spo2!)}%',
              number: result.spo2 != null,
            ),
          _ResultRow(
            label: l10n.resultHrv,
            value: result.hrvMs != null
                ? '${Fmt.whole(result.hrvMs!)} ${l10n.unitMs}'
                : result.hrvUnavailable
                    ? l10n.resultHrvUnavailable
                    : '--',
            number: result.hrvMs != null,
          ),
          _ResultRow(
            label: l10n.resultQuality,
            value: result.quality == null ? '--' : '${result.quality}/100',
            number: result.quality != null,
          ),
          _ResultRow(
            label: l10n.resultDuration,
            value: l10n.secondsValue('${result.duration.inSeconds}'),
          ),
          _ResultRow(label: l10n.resultTime, value: Fmt.clock(result.startedAt), number: true),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: p.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(_endReason(l10n, result.endReason), style: theme.textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: MeasurePage.againKey,
                onPressed: controller.measureAgain,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.measureAgain),
              ),
              TextButton(onPressed: controller.backToChoice, child: Text(l10n.back)),
            ],
          ),
        ],
      ),
    );
  }
}

String _endReason(AppLocalizations l10n, SessionEndReason reason) => switch (reason) {
      SessionEndReason.stable => l10n.resultEndedEarly,
      SessionEndReason.hrvReceived => l10n.resultEndedWithHrv,
      SessionEndReason.timeout => l10n.resultEndedTimeout,
      SessionEndReason.cancelled => l10n.cancel,
    };

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, this.number = false});

  final String label;
  final String value;

  /// Numbers are laid out left to right in both languages.
  final bool number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: context.palette.muted))),
          Expanded(
            child: Text(
              value,
              textDirection: number ? TextDirection.ltr : null,
              textAlign: TextAlign.start,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      );
}

class _SiteChip extends StatelessWidget {
  const _SiteChip({required this.site});

  final MeasureSite site;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(site.icon, size: 18, color: p.muted),
        const SizedBox(width: 6),
        Text(site == MeasureSite.finger ? l10n.siteFinger : l10n.siteWrist,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// History

class _History extends ConsumerWidget {
  const _History({required this.history});

  final List<SessionResult> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SurfaceCard(
      key: MeasurePage.historyKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            l10n.historyTitle,
            trailing: history.isEmpty
                ? null
                : TextButton(
                    onPressed: ref.read(measureControllerProvider.notifier).clearHistory,
                    child: Text(l10n.clearHistory),
                  ),
          ),
          Text(l10n.historyNote, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.historyEmpty, style: theme.textTheme.bodyMedium),
            )
          else
            for (final r in history) _HistoryRow(result: r),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.result});

  final SessionResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final theme = Theme.of(context);
    final bpm = result.bpm;
    final zone = bpm == null ? null : HeartRateZone.forBpm(bpm);
    final extras = [
      if (result.spo2 != null) '${l10n.resultSpo2} ${Fmt.whole(result.spo2!)}%',
      if (result.hrvMs != null) '${l10n.resultHrv} ${Fmt.whole(result.hrvMs!)} ${l10n.unitMs}',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.rule))),
      child: Row(
        children: [
          Text(Fmt.clock(result.startedAt), textDirection: TextDirection.ltr, style: theme.textTheme.bodySmall),
          const SizedBox(width: 12),
          Icon(result.site.icon, size: 18, color: p.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (zone == null)
                  Text(l10n.historyNoReading, style: theme.textTheme.bodyMedium?.copyWith(color: p.muted))
                else
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: zone.color(p), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text('${Fmt.whole(bpm!)} ${l10n.unitBpm}',
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(zone.label(l10n), style: TextStyle(color: zone.color(p), fontSize: 13)),
                    ],
                  ),
                if (extras.isNotEmpty) Text(extras.join(' · '), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

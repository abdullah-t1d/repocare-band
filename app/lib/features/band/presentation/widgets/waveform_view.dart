import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/motion.dart';
import '../../domain/enums.dart';
import '../../domain/live_assessment.dart';
import '../l10n_labels.dart';
import '../providers/band_providers.dart';
import '../providers/live_controller.dart';
import '../providers/waveform_buffer.dart';

/// Live pulse wave (last 6 s) on ECG paper, with a tick on every beat.
///
/// Time runs left to right in both languages, like any chart. The colour
/// follows the heart-rate zone; a weak signal fades the trace.
class WaveformView extends ConsumerStatefulWidget {
  const WaveformView({super.key});

  @override
  ConsumerState<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends ConsumerState<WaveformView> {
  final _AutoScale _scale = _AutoScale();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final buffer = ref.watch(waveformProvider);
    final connected = ref.watch(connectionControllerProvider.select((s) => s.isConnected));
    final metrics = ref.watch(liveControllerProvider.select((s) => s.metrics));
    final quality = metrics == null ? SignalQuality.none : signalQualityOf(metrics);
    final idleColor = Color.lerp(p.muted, p.sheet, 0.1)!;
    final target = metrics?.bpm == null ? idleColor : heartRateColor(metrics!.bpm, p);

    return Stack(
      children: [
        Positioned.fill(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: target),
            duration: context.motion(AppTheme.bodyTransition),
            builder: (context, color, _) => AnimatedOpacity(
              opacity: connected ? math.max(quality.opacity, 0.55) : 1,
              duration: context.motion(AppTheme.bodyTransition),
              child: CustomPaint(
                painter: _WaveformPainter(
                  buffer: buffer,
                  scale: _scale,
                  color: color ?? target,
                  gridMinor: p.gridMinor,
                  gridMajor: p.gridMajor,
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 14,
          start: 16,
          child: Text('${l10n.pulseWave} · ${l10n.lastSixSeconds}',
              style: Theme.of(context).textTheme.labelMedium),
        ),
        if (!connected)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.waveEmpty,
                  textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 15)),
            ),
          ),
      ],
    );
  }
}

/// Vertical range that follows the signal smoothly instead of jumping.
class _AutoScale {
  double lo = -50;
  double hi = 50;

  void follow(double min, double max) {
    if (max - min < 20) {
      min -= 10;
      max += 10;
    }
    lo += (min - lo) * 0.08;
    hi += (max - hi) * 0.08;
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.buffer,
    required this.scale,
    required this.color,
    required this.gridMinor,
    required this.gridMajor,
  }) : super(repaint: buffer);

  /// 6 s split into 0.2 s squares, a major line every second.
  static const int _columns = 30;

  final WaveformBuffer buffer;
  final _AutoScale scale;
  final Color color;
  final Color gridMinor;
  final Color gridMajor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final step = w / _columns;
    final minor = Paint()
      ..color = gridMinor
      ..strokeWidth = 1;
    final major = Paint()
      ..color = gridMajor
      ..strokeWidth = 1;

    for (var i = 0; i <= _columns; i++) {
      final x = w - i * step;
      canvas.drawLine(Offset(x, 0), Offset(x, h), i % 5 == 0 ? major : minor);
    }
    var row = 0;
    for (var y = h; y >= 0; y -= step, row++) {
      canvas.drawLine(Offset(0, y), Offset(w, y), row % 5 == 0 ? major : minor);
    }

    final n = buffer.length;
    if (n < 2) return;

    var min = double.infinity;
    var max = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      final v = buffer[i];
      if (v < min) min = v;
      if (v > max) max = v;
    }
    scale.follow(min, max);
    final pad = (scale.hi - scale.lo) * 0.15;
    final span = scale.hi - scale.lo + 2 * pad;
    double yOf(double v) => h - (v - scale.lo + pad) / span * (h - 40) - 12;
    final xStep = w / (buffer.capacity - 1);

    final tick = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final age in buffer.beatAges) {
      final x = w - age * xStep;
      canvas.drawLine(Offset(x, h - 16), Offset(x, h - 4), tick);
    }

    final path = Path();
    for (var i = 0; i < n; i++) {
      final x = w - (n - 1 - i) * xStep;
      final y = yOf(buffer[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.color != color ||
      old.gridMinor != gridMinor ||
      old.gridMajor != gridMajor ||
      old.buffer != buffer;
}

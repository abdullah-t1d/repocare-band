import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/band_constants.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/format.dart';
import '../l10n_labels.dart';
import '../providers/band_providers.dart';
import '../providers/live_controller.dart';

/// Heart rate over the last two minutes.
///
/// The line breaks where no reading was available instead of drawing a
/// straight line across the gap.
class TrendChart extends ConsumerWidget {
  const TrendChart({this.height = 190, super.key});

  /// A longer gap between readings breaks the line.
  static const Duration maxGap = Duration(seconds: 3);

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final trend = ref.watch(liveControllerProvider.select((s) => s.trend));
    final now = ref.watch(nowProvider)();

    if (trend.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text(context.l10n.trendEmpty, style: TextStyle(color: p.muted))),
      );
    }

    final spots = <FlSpot>[];
    DateTime? previous;
    for (final point in trend) {
      if (previous != null && point.time.difference(previous) > maxGap) spots.add(FlSpot.nullSpot);
      spots.add(FlSpot(-now.difference(point.time).inMilliseconds / 1000, point.bpm));
      previous = point.time;
    }
    final bpms = trend.map((t) => t.bpm);
    final minY = (math.min(50, bpms.reduce(math.min) - 5) / 10).floorToDouble() * 10;
    final maxY = (math.max(110, bpms.reduce(math.max) + 5) / 10).ceilToDouble() * 10;
    final color = heartRateColor(trend.last.bpm, p);
    final window = BandConstants.trendWindow.inSeconds.toDouble();
    final axisStyle = TextStyle(color: p.muted, fontSize: 11.5);

    return SizedBox(
      height: height,
      // Time runs left to right in both languages.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LineChart(
          duration: Duration.zero,
          LineChartData(
            minX: -window,
            maxX: 0,
            minY: minY,
            maxY: maxY,
            clipData: const FlClipData.all(),
            lineTouchData: const LineTouchData(enabled: false),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY - minY > 80 ? 20 : 10,
              getDrawingHorizontalLine: (_) => FlLine(color: p.rule, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: maxY - minY > 80 ? 20 : 10,
                  getTitlesWidget: (v, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(v.round().toString(), style: axisStyle),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 30,
                  getTitlesWidget: (v, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      v == 0 ? '0' : '-${Fmt.minutesSeconds(Duration(seconds: -v.round()))}',
                      style: axisStyle,
                    ),
                  ),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.2,
                preventCurveOverShooting: true,
                color: color,
                barWidth: 2.4,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

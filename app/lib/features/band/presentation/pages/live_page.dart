import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/surface_card.dart';
import '../providers/band_providers.dart';
import '../providers/live_controller.dart';
import '../widgets/controls_panel.dart';
import '../widgets/demo_bar.dart';
import '../widgets/heart_rate_panel.dart';
import '../widgets/metric_tiles.dart';
import '../widgets/raw_panel.dart';
import '../widgets/trend_chart.dart';
import '../widgets/waveform_view.dart';

/// Live dashboard: heart rate, pulse wave, readouts, trend and controls.
class LivePage extends ConsumerWidget {
  const LivePage({super.key});

  /// Side by side above this width, stacked below.
  static const double wideBreakpoint = 860;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final conn = ref.watch(connectionControllerProvider);
    if (!conn.isConnected && !conn.isConnecting) return const NotConnectedView();

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= wideBreakpoint;
        const gap = SizedBox(height: 14, width: 14);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            if (conn.isDemo) ...[const DemoBar(), gap],
            SurfaceCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: wide
                  ? SizedBox(
                      height: 340,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(width: 320, child: HeartRatePanel()),
                          VerticalDivider(width: 1, color: context.palette.rule),
                          const Expanded(child: WaveformView()),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        const HeartRatePanel(),
                        Divider(height: 1, color: context.palette.rule),
                        const SizedBox(height: 230, child: WaveformView()),
                      ],
                    ),
            ),
            gap,
            const MetricTiles(),
            gap,
            if (c.maxWidth >= 1000)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _TrendCard(title: l10n.trendTitle)),
                    gap,
                    const Expanded(flex: 2, child: ControlsPanel()),
                  ],
                ),
              )
            else ...[
              _TrendCard(title: l10n.trendTitle),
              gap,
              const ControlsPanel(),
            ],
            gap,
            const RawPanel(),
          ],
        );
      },
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [CardTitle(title), const TrendChart()],
      ),
    );
  }
}

/// Shown on pages that need the band while it is not connected.
class NotConnectedView extends ConsumerWidget {
  const NotConnectedView({this.message, super.key});

  /// Replaces the default explanation.
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final theme = Theme.of(context);
    final canExport = ref.watch(liveControllerProvider.select((s) => s.canExport));
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: p.sheet, shape: BoxShape.circle, boxShadow: p.cardShadow),
                child: Icon(Icons.watch_off_outlined, size: 40, color: p.muted),
              ),
              const SizedBox(height: 20),
              Text(l10n.notConnectedTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message ?? l10n.notConnectedBody,
                  textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: p.muted)),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.devices),
                    icon: const Icon(Icons.watch_outlined),
                    label: Text(l10n.goToDevices),
                  ),
                  if (canExport)
                    OutlinedButton.icon(
                      onPressed: ref.read(liveControllerProvider.notifier).exportCsv,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(l10n.exportCsv),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/surface_card.dart';
import '../providers/live_controller.dart';
import '../providers/waveform_buffer.dart';

/// IR, RED, PI, LED current, stored beats and the last device messages.
class RawPanel extends ConsumerWidget {
  const RawPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final theme = Theme.of(context);
    final live = ref.watch(liveControllerProvider);
    final m = live.metrics;
    final raw = ref.watch(waveformProvider).raw;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(l10n.rawTitle),
          ValueListenableBuilder<RawSample?>(
            valueListenable: raw,
            builder: (context, sample, _) => Column(
              children: [
                _Row('IR', sample == null ? '--' : Fmt.grouped(sample.ir)),
                _Row('RED', sample == null ? '--' : Fmt.grouped(sample.red)),
              ],
            ),
          ),
          _Row(l10n.perfusionIndex,
              m?.perfusionIndex == null ? '--' : '${Fmt.fixed(m!.perfusionIndex!, 2)}%'),
          _Row(l10n.ledCurrent,
              m?.ledCurrentMa == null ? '--' : '${Fmt.fixed(m!.ledCurrentMa!, 1)} mA'),
          _Row(l10n.storedBeats, '${m?.storedBeats ?? 0}'),
          if (live.channel != null) _Row(l10n.signalChannel, live.channel!.name.toUpperCase()),
          const SizedBox(height: 12),
          Text(l10n.deviceMessages, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          if (live.logs.isEmpty)
            Text(l10n.noMessages, style: theme.textTheme.bodySmall)
          else
            for (final line in live.logs)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  line,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: p.muted,
                    fontSize: 12.5,
                    fontFamily: AppTheme.latinFont,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: p.muted, fontSize: 14))),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 14, fontFeatures: AppTheme.tabularFigures),
          ),
        ],
      ),
    );
  }
}

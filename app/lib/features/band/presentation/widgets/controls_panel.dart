import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/enums.dart';
import '../providers/band_providers.dart';
import '../providers/live_controller.dart';

/// LED brightness, reset, recording and CSV export.
class ControlsPanel extends ConsumerWidget {
  const ControlsPanel({super.key});

  static const Key recordKey = ValueKey('record-button');
  static const Key exportKey = ValueKey('export-button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final theme = Theme.of(context);
    final live = ref.watch(liveControllerProvider);
    final controller = ref.read(liveControllerProvider.notifier);
    final conn = ref.watch(connectionControllerProvider);
    final canCommand = conn.isConnected && !conn.isDemo;
    final led = live.metrics?.ledMode ?? LedMode.auto;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(l10n.controlsTitle),
          Text(l10n.ledBrightness, style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Directionality(
            // Levels 1–4 read left to right like the firmware's numbering.
            textDirection: TextDirection.ltr,
            child: SegmentedButton<LedMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                for (final mode in LedMode.values)
                  ButtonSegment(
                    value: mode,
                    label: Text(mode.isAuto ? l10n.ledAuto : '${mode.level}'),
                  ),
              ],
              selected: {led},
              onSelectionChanged: canCommand ? (s) => controller.setLed(s.first) : null,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: canCommand ? controller.resetAnalysis : null,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text(l10n.resetAnalysis),
              ),
              OutlinedButton.icon(
                key: recordKey,
                onPressed: conn.isConnected || live.recording ? controller.toggleRecording : null,
                style: live.recording
                    ? OutlinedButton.styleFrom(foregroundColor: p.pulse, side: BorderSide(color: p.pulse))
                    : null,
                icon: Icon(live.recording ? Icons.stop_circle_outlined : Icons.fiber_manual_record,
                    size: 18, color: live.recording ? p.pulse : null),
                label: Text(live.recording ? l10n.stopRecording : l10n.startRecording),
              ),
              OutlinedButton.icon(
                key: exportKey,
                onPressed: live.canExport ? controller.exportCsv : null,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(l10n.exportCsv),
              ),
            ],
          ),
          if (live.recording || live.canExport) ...[
            const SizedBox(height: 8),
            Text(l10n.recordedRows('${live.recordedRows}'), style: theme.textTheme.bodySmall),
          ],
          if (conn.isDemo) ...[
            const SizedBox(height: 8),
            Text(l10n.demoCommandsNote, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

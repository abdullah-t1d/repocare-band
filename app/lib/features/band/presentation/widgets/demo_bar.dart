import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../data/transport/demo_replay_transport.dart';
import '../l10n_labels.dart';
import '../providers/band_providers.dart';

/// Playback controls while a demo recording is playing.
class DemoBar extends ConsumerWidget {
  const DemoBar({super.key});

  static const Key pauseKey = ValueKey('demo-pause');
  static const Key restartKey = ValueKey('demo-restart');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(demoPlaybackProvider).valueOrNull;
    final transport = ref.watch(demoTransportProvider);
    if (playback == null || transport == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final p = context.palette;
    final theme = Theme.of(context);

    return SurfaceCard(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 12, 10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_outline, color: p.oxy),
              const SizedBox(width: 8),
              // Flexible: on a phone the recording name wraps instead of overflowing.
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${l10n.demoPlayback} · ', style: theme.textTheme.labelMedium),
                    TextSpan(text: playback.recording.title(l10n), style: theme.textTheme.titleMedium),
                  ]),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: pauseKey,
                tooltip: playback.paused ? l10n.demoResume : l10n.demoPause,
                onPressed: playback.paused ? transport.resume : transport.pause,
                icon: Icon(playback.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              ),
              IconButton(
                key: restartKey,
                tooltip: l10n.demoRestart,
                onPressed: transport.restart,
                icon: const Icon(Icons.replay_rounded),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: l10n.demoSpeed,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      for (final s in DemoReplayTransport.speeds)
                        ButtonSegment(value: s, label: Text('${s}x')),
                    ],
                    selected: {playback.speed},
                    onSelectionChanged: (s) => transport.setSpeed(s.first),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: playback.progress,
                    minHeight: 5,
                    color: p.oxy,
                    backgroundColor: p.track,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${Fmt.minutesSeconds(playback.position)} / ${Fmt.minutesSeconds(playback.length)}',
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

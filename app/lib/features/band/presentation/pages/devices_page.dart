import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../data/transport/demo_recording.dart';
import '../../data/transport/transport_factory.dart';
import '../../domain/enums.dart';
import '../l10n_labels.dart';
import '../providers/band_providers.dart';
import '../widgets/connection_widgets.dart';

/// Pick USB or a demo recording and connect.
class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  static const Key connectKey = ValueKey('connect-button');
  static const Key disconnectKey = ValueKey('disconnect-button');

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  late TransportKind _kind;
  late DemoRecording _recording;

  @override
  void initState() {
    super.initState();
    final conn = ref.read(connectionControllerProvider);
    final request = conn.request;
    _recording = request is DemoRequest ? request.recording : DemoRecording.fingerRest;
    // Without Web Serial, demo mode is the only choice that works.
    _kind = request?.kind ?? (conn.usbSupported ? TransportKind.usbSerial : TransportKind.demo);
  }

  TransportRequest get _request => switch (_kind) {
        TransportKind.usbSerial => const UsbSerialRequest(),
        TransportKind.demo => DemoRequest(_recording),
        TransportKind.ble => const BleRequest(),
      };

  Future<void> _connect() async {
    final ok = await ref.read(connectionControllerProvider.notifier).connect(_request);
    if (ok && mounted) context.go(AppRoutes.live);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final conn = ref.watch(connectionControllerProvider);
    final busy = conn.isConnected || conn.isConnecting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(l10n.devicesTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(l10n.devicesSubtitle, style: theme.textTheme.bodySmall),
        const SizedBox(height: 20),
        if (!conn.usbSupported) ...[
          NoticeBanner(icon: Icons.public_off, message: l10n.unsupportedBrowser),
          const SizedBox(height: 16),
        ],
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SurfaceCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DeviceHeader(),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  Text(l10n.connectionType, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<TransportKind>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: TransportKind.usbSerial,
                        icon: const Icon(Icons.usb, size: 18),
                        label: Text(l10n.transportUsb),
                      ),
                      ButtonSegment(
                        value: TransportKind.demo,
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        label: Text(l10n.transportDemo),
                      ),
                      ButtonSegment(
                        value: TransportKind.ble,
                        enabled: false,
                        icon: const Icon(Icons.bluetooth, size: 18),
                        label: Text('${l10n.transportBle} · ${l10n.comingSoon}'),
                      ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: busy ? null : (s) => setState(() => _kind = s.first),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    alignment: AlignmentDirectional.topStart,
                    child: switch (_kind) {
                      TransportKind.usbSerial => const _UsbSteps(),
                      TransportKind.demo => _RecordingPicker(
                          selected: _recording,
                          enabled: !busy,
                          onChanged: (r) => setState(() => _recording = r),
                        ),
                      TransportKind.ble => Text(l10n.bleNote, style: theme.textTheme.bodyMedium),
                    },
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (conn.isConnected) ...[
                        FilledButton.icon(
                          onPressed: () => context.go(AppRoutes.live),
                          icon: const Icon(Icons.monitor_heart_outlined),
                          label: Text(l10n.openLive),
                        ),
                        OutlinedButton.icon(
                          key: DevicesPage.disconnectKey,
                          onPressed: ref.read(connectionControllerProvider.notifier).disconnect,
                          icon: const Icon(Icons.link_off, size: 18),
                          label: Text(l10n.disconnect),
                        ),
                      ] else
                        FilledButton.icon(
                          key: DevicesPage.connectKey,
                          onPressed: conn.isConnecting ||
                                  _kind == TransportKind.ble ||
                                  (_kind == TransportKind.usbSerial && !conn.usbSupported)
                              ? null
                              : _connect,
                          icon: conn.isConnecting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.link),
                          label: Text(conn.isConnecting ? l10n.statusConnecting : l10n.connect),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: context.palette.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.browserNote, style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: p.paper, borderRadius: AppTheme.controlRadius),
          child: Icon(Icons.watch_outlined, color: p.pulse, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.deviceName, style: theme.textTheme.titleLarge),
              Text(l10n.deviceHardware, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const ConnectionStatusChip(),
      ],
    );
  }
}

class _UsbSteps extends StatelessWidget {
  const _UsbSteps();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final steps = [l10n.usbStep1, l10n.usbStep2, l10n.usbStep3];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.paper, shape: BoxShape.circle),
                  child: Text('${i + 1}', style: TextStyle(color: p.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i], style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecordingPicker extends StatelessWidget {
  const _RecordingPicker({required this.selected, required this.enabled, required this.onChanged});

  final DemoRecording selected;
  final bool enabled;
  final ValueChanged<DemoRecording> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.demoPickRecording, style: theme.textTheme.labelMedium),
        const SizedBox(height: 10),
        for (final r in DemoRecording.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              selected: r == selected,
              inMutuallyExclusiveGroup: true,
              child: InkWell(
                key: ValueKey('recording-${r.name}'),
                borderRadius: AppTheme.controlRadius,
                onTap: enabled ? () => onChanged(r) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: AppTheme.controlRadius,
                    border: Border.all(color: r == selected ? p.oxy : p.rule, width: r == selected ? 1.5 : 1),
                    color: r == selected ? p.oxy.withValues(alpha: 0.06) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(r == selected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: r == selected ? p.oxy : p.muted, size: 20),
                      const SizedBox(width: 12),
                      Icon(r.site.icon, color: p.muted, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title(l10n), style: theme.textTheme.titleMedium),
                            Text(r.detail(l10n), style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

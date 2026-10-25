import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/motion.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../data/transport/band_transport.dart';
import '../../domain/enums.dart';
import '../l10n_labels.dart';
import '../providers/band_providers.dart';

/// Dot and label for the connection state.
class ConnectionStatusChip extends ConsumerWidget {
  const ConnectionStatusChip({this.compact = false, super.key});

  /// Only the dot, for narrow headers.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final state = ref.watch(connectionControllerProvider.select((s) => s.status.connection));
    final label = state.label(context.l10n);
    final dot = AnimatedContainer(
      duration: context.motion(const Duration(milliseconds: 300)),
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: state.color(p), shape: BoxShape.circle),
    );
    return Semantics(
      label: label,
      child: Tooltip(
        message: compact ? label : '',
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 6),
          decoration: BoxDecoration(
            color: p.sheet,
            border: Border.all(color: p.rule),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot,
              if (!compact) ...[
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: p.muted, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Problems with the link, shown on every page: a lost connection with a
/// Reconnect button (which opens the port picker again), a busy port, and
/// the firmware's "sensor not found" message.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  static const Key reconnectKey = ValueKey('reconnect-button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final conn = ref.watch(connectionControllerProvider);
    final controller = ref.read(connectionControllerProvider.notifier);
    final failure = conn.failure;

    final banners = <Widget>[
      if (failure != null)
        NoticeBanner(
          icon: failure.code == TransportFailureCode.connectionLost ? Icons.usb_off : Icons.error_outline,
          message: failure.message(l10n),
          actions: [
            if (failure.canReconnect && conn.request?.kind != TransportKind.ble)
              FilledButton.icon(
                key: reconnectKey,
                onPressed: conn.isConnecting ? null : controller.reconnect,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.reconnect),
              ),
            const SizedBox(width: 4),
            TextButton(onPressed: controller.dismissFailure, child: Text(l10n.dismiss)),
          ],
        ),
      if (conn.isConnected && conn.status.sensorError)
        NoticeBanner(icon: Icons.cable, message: l10n.errorSensorMissing),
    ];
    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          for (final b in banners) Padding(padding: const EdgeInsets.only(bottom: 8), child: b),
        ],
      ),
    );
  }
}

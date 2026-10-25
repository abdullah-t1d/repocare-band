import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_palette.dart';
import '../data/transport/band_transport.dart';
import '../data/transport/demo_recording.dart';
import '../domain/enums.dart';
import '../domain/heart_rate_zone.dart';

/// Labels and colours for domain values. Kept in the presentation layer so
/// the domain stays free of UI text.
extension SignalQualityLabel on SignalQuality {
  String label(AppLocalizations l10n) => switch (this) {
        SignalQuality.excellent => l10n.qualityExcellent,
        SignalQuality.acceptable => l10n.qualityAcceptable,
        SignalQuality.weak => l10n.qualityWeak,
        SignalQuality.none => l10n.qualityNone,
      };

  Color color(AppPalette p) => switch (this) {
        SignalQuality.excellent => p.oxy,
        SignalQuality.acceptable => p.warn,
        SignalQuality.weak => p.pulse,
        SignalQuality.none => p.idle,
      };

  /// Weak signals fade the numbers and the wave; excellent ones are crisp.
  double get opacity => switch (this) {
        SignalQuality.excellent => 1,
        SignalQuality.acceptable => 0.88,
        SignalQuality.weak => 0.55,
        SignalQuality.none => 0.4,
      };
}

extension LiveHintLabel on LiveHint {
  String label(AppLocalizations l10n) => switch (this) {
        LiveHint.saturated => l10n.hintSaturated,
        LiveHint.noContact => l10n.hintNoContact,
        LiveHint.motion => l10n.hintMotion,
        LiveHint.settling => l10n.hintSettling,
        LiveHint.weakSignal => l10n.hintWeakSignal,
        LiveHint.stable => l10n.hintStable,
      };
}

extension HeartRateZoneStyle on HeartRateZone {
  String label(AppLocalizations l10n) => switch (this) {
        HeartRateZone.low => l10n.zoneLow,
        HeartRateZone.normal => l10n.zoneNormal,
        HeartRateZone.elevated => l10n.zoneElevated,
        HeartRateZone.high => l10n.zoneHigh,
      };

  /// Calm, non-diagnostic sentence for the zone.
  String caption(AppLocalizations l10n) => switch (this) {
        HeartRateZone.low => l10n.zoneLowCaption,
        HeartRateZone.normal => l10n.zoneNormalCaption,
        HeartRateZone.elevated => l10n.zoneElevatedCaption,
        HeartRateZone.high => l10n.zoneHighCaption,
      };

  Color color(AppPalette p) => switch (this) {
        HeartRateZone.low => p.zoneLow,
        HeartRateZone.normal => p.zoneNormal,
        HeartRateZone.elevated => p.zoneElevated,
        HeartRateZone.high => p.zoneHigh,
      };
}

/// Colour of a heart rate, or a neutral colour when there is none yet.
Color heartRateColor(double? bpm, AppPalette p) =>
    bpm == null ? p.muted : HeartRateZone.forBpm(bpm).color(p);

extension ConnectionStateLabel on BandConnectionState {
  String label(AppLocalizations l10n) => switch (this) {
        BandConnectionState.connected => l10n.statusConnected,
        BandConnectionState.connecting => l10n.statusConnecting,
        BandConnectionState.disconnected => l10n.statusDisconnected,
      };

  Color color(AppPalette p) => switch (this) {
        BandConnectionState.connected => p.ok,
        BandConnectionState.connecting => p.warn,
        BandConnectionState.disconnected => p.idle,
      };
}

extension TransportFailureMessage on TransportFailure {
  String message(AppLocalizations l10n) => switch (code) {
        TransportFailureCode.unsupportedBrowser => l10n.unsupportedBrowser,
        TransportFailureCode.portBusy => l10n.errorPortBusy,
        TransportFailureCode.connectionLost => l10n.errorConnectionLost,
        TransportFailureCode.openFailed ||
        TransportFailureCode.noPortSelected =>
          l10n.errorOpenFailed,
        TransportFailureCode.recordingUnavailable => l10n.errorRecordingUnavailable,
        TransportFailureCode.notImplemented => l10n.errorNotImplemented,
      };
}

extension DemoRecordingLabel on DemoRecording {
  String title(AppLocalizations l10n) => switch (this) {
        DemoRecording.fingerRest => l10n.recFingerRest,
        DemoRecording.wristBackRest => l10n.recWristBack,
        DemoRecording.wristInnerNoPulse => l10n.recWristInner,
      };

  String detail(AppLocalizations l10n) => switch (this) {
        DemoRecording.fingerRest => l10n.recFingerRestDetail,
        DemoRecording.wristBackRest => l10n.recWristBackDetail,
        DemoRecording.wristInnerNoPulse => l10n.recWristInnerDetail,
      };
}

extension MeasureSiteStyle on MeasureSite {
  IconData get icon => switch (this) {
        MeasureSite.finger => Icons.fingerprint,
        MeasureSite.wrist => Icons.watch_outlined,
      };
}

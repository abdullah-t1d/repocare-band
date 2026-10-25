import '../../../core/constants/band_constants.dart';
import 'band_event.dart';
import 'enums.dart';

/// Quality label for [metrics]: none without skin contact, otherwise by the
/// 75 / 45 thresholds used across the project.
SignalQuality signalQualityOf(Metrics metrics) {
  if (!metrics.contact) return SignalQuality.none;
  return signalQualityForScore(metrics.quality);
}

/// Quality label for a 0–100 score.
SignalQuality signalQualityForScore(int quality) {
  if (quality >= BandConstants.qualityExcellent) return SignalQuality.excellent;
  if (quality >= BandConstants.qualityAcceptable) return SignalQuality.acceptable;
  return SignalQuality.weak;
}

/// The BPM is the firmware's held value, not a live one: firmware v2.2 keeps
/// the last good BPM for up to 10 s after the signal drops and sends it with
/// the low quality of the current signal.
bool isHeldHeartRate(Metrics metrics) {
  final bpm = metrics.bpm;
  return bpm != null && bpm > 0 && metrics.quality < BandConstants.heldBpmQuality;
}

/// Skin contact but no RMSSD yet: the firmware's 60 s window is not full.
bool isWaitingForHrv(Metrics metrics) => metrics.contact && metrics.rmssdMs == null;

/// The app's own count of consecutive seconds (one per `M` line) with quality
/// ≥ 45, shown as progress towards the first RMSSD. A weaker reading restarts
/// it at 0. It only estimates the firmware's state; HRV itself always comes
/// from the firmware.
int nextHrvSteadySeconds(int current, Metrics metrics) =>
    metrics.quality >= BandConstants.qualityAcceptable ? current + 1 : 0;

/// Hint for the live dashboard. The order matches the prototype dashboard:
/// a clipped signal first, then contact, motion, settling and weak signal.
LiveHint liveHintFor(Metrics metrics) {
  if (metrics.saturated) return LiveHint.saturated;
  if (!metrics.contact) return LiveHint.noContact;
  if (metrics.motion) return LiveHint.motion;
  if (metrics.bpm == null) return LiveHint.settling;
  if (metrics.quality < BandConstants.qualityAcceptable) return LiveHint.weakSignal;
  return LiveHint.stable;
}

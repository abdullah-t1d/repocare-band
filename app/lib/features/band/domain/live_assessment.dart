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

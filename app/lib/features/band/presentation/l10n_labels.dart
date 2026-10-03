import '../../../core/l10n/l10n.dart';
import '../domain/enums.dart';

/// Arabic labels for domain enums. Kept in the presentation layer so the
/// domain stays free of UI text.
extension SignalQualityLabel on SignalQuality {
  String label(AppLocalizations l10n) => switch (this) {
        SignalQuality.excellent => l10n.qualityExcellent,
        SignalQuality.acceptable => l10n.qualityAcceptable,
        SignalQuality.weak => l10n.qualityWeak,
        SignalQuality.none => l10n.qualityNone,
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

import 'package:flutter/foundation.dart';

import '../../../../core/constants/band_constants.dart';
import '../enums.dart';

/// Rules of a guided measurement for one body site.
@immutable
class MeasureProtocol {
  const MeasureProtocol({
    required this.site,
    required this.maxDuration,
    this.stableQuality,
    this.stableWindow,
    this.endsOnHrv = false,
    this.goodQuality = BandConstants.qualityAcceptable,
    this.minGoodReadings = 5,
  }) : assert((stableQuality == null) == (stableWindow == null));

  /// Fingertip: up to 75 s. Heart rate and SpO2 appear early, but the
  /// measurement goes on until the firmware reports HRV, which needs about
  /// 45–60 s of steady signal (firmware v2.2).
  static const MeasureProtocol finger = MeasureProtocol(
    site: MeasureSite.finger,
    maxDuration: Duration(seconds: 75),
    endsOnHrv: true,
  );

  /// Back of the wrist: 60 s, ends early after 10 s with quality ≥ 60.
  static const MeasureProtocol wrist = MeasureProtocol(
    site: MeasureSite.wrist,
    maxDuration: Duration(seconds: 60),
    stableQuality: 60,
    stableWindow: Duration(seconds: 10),
  );

  static MeasureProtocol forSite(MeasureSite site) => switch (site) {
        MeasureSite.finger => finger,
        MeasureSite.wrist => wrist,
      };

  final MeasureSite site;

  /// The measurement stops at this time at the latest.
  final Duration maxDuration;

  /// Quality needed, without interruption, to end early; `null` when a stable
  /// heart rate does not end the measurement.
  final int? stableQuality;

  /// How long [stableQuality] must hold to end early.
  final Duration? stableWindow;

  /// The measurement ends as soon as a valid HRV (RMSSD) arrives.
  final bool endsOnHrv;

  /// Quality needed for a reading to count towards the result.
  final int goodQuality;

  /// Readings at [goodQuality] needed for a heart-rate result.
  final int minGoodReadings;

  /// SpO2 is only reported for the fingertip.
  bool get reportsSpo2 => site == MeasureSite.finger;
}

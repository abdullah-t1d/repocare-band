import 'package:flutter/foundation.dart';

import '../../../../core/constants/band_constants.dart';
import '../enums.dart';

/// Rules of a guided measurement for one body site.
@immutable
class MeasureProtocol {
  const MeasureProtocol({
    required this.site,
    required this.maxDuration,
    required this.stableQuality,
    required this.stableWindow,
    this.goodQuality = BandConstants.qualityAcceptable,
    this.minGoodReadings = 5,
  });

  /// Fingertip: 30 s, ends early after 8 s with quality ≥ 75.
  static const MeasureProtocol finger = MeasureProtocol(
    site: MeasureSite.finger,
    maxDuration: Duration(seconds: 30),
    stableQuality: 75,
    stableWindow: Duration(seconds: 8),
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

  /// Quality needed, without interruption, to end early.
  final int stableQuality;

  /// How long [stableQuality] must hold to end early.
  final Duration stableWindow;

  /// Quality needed for a reading to count when the time runs out.
  final int goodQuality;

  /// Readings at [goodQuality] needed for a result when the time runs out.
  final int minGoodReadings;

  /// SpO2 is only reported for the fingertip.
  bool get reportsSpo2 => site == MeasureSite.finger;
}

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'repoCare Band';

  @override
  String get appSubtitle => 'Live readings from the MAX30102 pulse sensor';

  @override
  String get navDevices => 'Devices';

  @override
  String get navLive => 'Live readings';

  @override
  String get navMeasure => 'Guided measurement';

  @override
  String get footerDisclaimer => 'Graduation project prototype, non-diagnostic';

  @override
  String get languageTooltip => 'Language';

  @override
  String get themeToDark => 'Switch to dark mode';

  @override
  String get themeToLight => 'Switch to light mode';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusDisconnected => 'Not connected';

  @override
  String get statusConnecting => 'Connecting';

  @override
  String get devicesTitle => 'Connect your band';

  @override
  String get devicesSubtitle => 'Choose how to connect, then press Connect.';

  @override
  String get deviceName => 'RepoCare Band';

  @override
  String get deviceHardware => 'Seeed XIAO nRF52840 Sense · MAX30102';

  @override
  String get connectionType => 'Connection';

  @override
  String get transportUsb => 'USB';

  @override
  String get transportDemo => 'Demo';

  @override
  String get transportBle => 'Bluetooth';

  @override
  String get comingSoon => 'Soon';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get openLive => 'Open live readings';

  @override
  String get browserNote => 'USB needs Chrome or Edge on a computer. Demo mode works in any browser.';

  @override
  String get unsupportedBrowser => 'Open this site in Chrome or Edge on a computer';

  @override
  String get usbStep1 => 'Upload repocare_finger or repocare_wrist to the board.';

  @override
  String get usbStep2 => 'Close the Arduino Serial Monitor.';

  @override
  String get usbStep3 => 'Press Connect and choose the band\'s port.';

  @override
  String get bleNote => 'A wireless link needs the band\'s Bluetooth firmware, which is still in development.';

  @override
  String get demoPickRecording => 'Choose a real recording to play';

  @override
  String get recFingerRest => 'Fingertip at rest';

  @override
  String get recFingerRestDetail => '80 s · 65–72 bpm, high quality';

  @override
  String get recWristBack => 'Back of the wrist at rest';

  @override
  String get recWristBackDetail => '221 s · 61–71 bpm, reading available about 60% of the time';

  @override
  String get recWristInner => 'Inner wrist (no pulse)';

  @override
  String get recWristInnerDetail => '134 s · negative example: the band correctly shows no number';

  @override
  String get errorPortBusy => 'Close Arduino Serial Monitor or any other page connected to the band.';

  @override
  String get errorConnectionLost => 'The connection to the band was lost (cable unplugged or board reset after an upload). Plug it in and press Reconnect.';

  @override
  String get errorOpenFailed => 'The port could not be opened. Unplug the band, plug it in again and retry.';

  @override
  String get errorRecordingUnavailable => 'The demo recording could not be loaded.';

  @override
  String get errorNotImplemented => 'Bluetooth is not available yet.';

  @override
  String get errorSensorMissing => 'Sensor not found. Check the wiring: blue to D4, yellow to D5, red to 3V3, black to GND.';

  @override
  String get notConnectedTitle => 'Band not connected';

  @override
  String get notConnectedBody => 'Connect the band over USB or play a demo recording from the Devices page.';

  @override
  String get goToDevices => 'Go to Devices';

  @override
  String get demoPlayback => 'Demo playback';

  @override
  String get demoPause => 'Pause';

  @override
  String get demoResume => 'Resume';

  @override
  String get demoRestart => 'Restart';

  @override
  String get demoSpeed => 'Speed';

  @override
  String get heartRate => 'Heart rate';

  @override
  String get unitBpm => 'bpm';

  @override
  String get unitBpmLong => 'beats per minute';

  @override
  String get unitMs => 'ms';

  @override
  String get zoneLow => 'Low';

  @override
  String get zoneNormal => 'Normal';

  @override
  String get zoneElevated => 'Elevated';

  @override
  String get zoneHigh => 'High';

  @override
  String get zoneLowCaption => 'Lower than usual at rest';

  @override
  String get zoneNormalCaption => 'Within the usual range at rest';

  @override
  String get zoneElevatedCaption => 'Higher than usual at rest';

  @override
  String get zoneHighCaption => 'Much higher than usual at rest; take a moment to relax and measure again';

  @override
  String get pulseWave => 'Pulse wave';

  @override
  String get lastSixSeconds => 'Last 6 seconds';

  @override
  String get waveEmpty => 'The pulse wave appears here once connected';

  @override
  String get spo2Title => 'Blood oxygen (SpO2)';

  @override
  String get estimateBadge => 'Estimate';

  @override
  String get spo2Note => 'Fingertip only, not calibrated';

  @override
  String get spo2WristNote => 'Not available on the wrist';

  @override
  String get hrvTitle => 'Heart-rate variability (HRV)';

  @override
  String get hrvNote => 'RMSSD from clean beats';

  @override
  String get qualityTitle => 'Signal quality';

  @override
  String get chipTempTitle => 'Sensor chip temperature';

  @override
  String get chipTempNote => 'Temperature of the sensor chip, not body temperature';

  @override
  String get qualityExcellent => 'Excellent';

  @override
  String get qualityAcceptable => 'Acceptable';

  @override
  String get qualityWeak => 'Weak';

  @override
  String get qualityNone => '--';

  @override
  String get hintSaturated => 'The light is too bright and the signal is clipped. Choose a lower brightness.';

  @override
  String get hintNoContact => 'Place your fingertip on the sensor with light, steady pressure.';

  @override
  String get hintMotion => 'Your hand moved. The reading pauses until you are still.';

  @override
  String get hintSettling => 'Rest your hand on the table and keep still… calculating heart rate.';

  @override
  String get hintWeakSignal => 'The signal is weak. Press more lightly and rest your hand on the table.';

  @override
  String get hintStable => 'The reading is stable.';

  @override
  String get trendTitle => 'Heart rate, last 2 minutes';

  @override
  String get trendEmpty => 'No readings yet';

  @override
  String get controlsTitle => 'Controls';

  @override
  String get ledBrightness => 'LED brightness';

  @override
  String get ledAuto => 'Auto';

  @override
  String get resetAnalysis => 'Reset analysis';

  @override
  String get startRecording => 'Start recording';

  @override
  String get stopRecording => 'Stop recording';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String recordedRows(String rows) {
    return '$rows rows recorded';
  }

  @override
  String get demoCommandsNote => 'Commands have no effect on a demo recording.';

  @override
  String get rawTitle => 'Raw data';

  @override
  String get perfusionIndex => 'Perfusion index (PI)';

  @override
  String get ledCurrent => 'LED current';

  @override
  String get storedBeats => 'Stored beats';

  @override
  String get signalChannel => 'Signal used';

  @override
  String get deviceMessages => 'Recent device messages';

  @override
  String get noMessages => 'No messages';

  @override
  String get measureTitle => 'Guided measurement';

  @override
  String get measureIntro => 'Choose how to measure. The app finishes early as soon as the reading is stable.';

  @override
  String get measureNeedsConnection => 'Connect the band first to start a measurement.';

  @override
  String get siteFinger => 'Finger measurement';

  @override
  String get siteFingerDetail => '30 seconds · heart rate, HRV and estimated SpO2';

  @override
  String get siteWrist => 'Wrist measurement';

  @override
  String get siteWristDetail => '60 seconds · heart rate from the back of the wrist';

  @override
  String get instructionsTitle => 'Before we start';

  @override
  String get instructionsFinger => 'Rest your hand on the table and lay your fingertip on the sensor without pressing. Stay still for 30 seconds.';

  @override
  String get instructionsWrist => 'Make sure the band sits snugly one finger-width above the wrist bone, and keep your hand still on a surface for one minute.';

  @override
  String get startMeasurement => 'Start measurement';

  @override
  String get waitingFinger => 'Place your finger on the sensor…';

  @override
  String get waitingWrist => 'Waiting for the sensor to touch your wrist…';

  @override
  String get measuringHoldStill => 'Hold still… measuring';

  @override
  String secondsLeft(String seconds) {
    return '$seconds s left';
  }

  @override
  String secondsValue(String seconds) {
    return '$seconds s';
  }

  @override
  String get stability => 'Reading stability';

  @override
  String get liveQuality => 'Signal quality now';

  @override
  String get firmwareMismatchFinger => 'The band is running the wrist sketch. For a finger measurement, upload repocare_finger.';

  @override
  String get firmwareMismatchWrist => 'The band is running the finger sketch. For a wrist measurement, upload repocare_wrist.';

  @override
  String get resultTitle => 'Result';

  @override
  String get resultFailed => 'We couldn\'t get an accurate reading. Keep your hand still and try again.';

  @override
  String get resultEndedEarly => 'Finished early because the reading was stable';

  @override
  String get resultHrv => 'HRV';

  @override
  String get resultSpo2 => 'SpO2 (estimate)';

  @override
  String get resultQuality => 'Quality';

  @override
  String get resultDuration => 'Duration';

  @override
  String get resultTime => 'Time';

  @override
  String get measureAgain => 'Measure again';

  @override
  String get measureDisconnected => 'The connection dropped during the measurement, so it stopped without a result.';

  @override
  String get historyTitle => 'Measurements this session';

  @override
  String get historyEmpty => 'No measurements yet';

  @override
  String get historyNote => 'Kept for this session only';

  @override
  String get historyNoReading => 'No reliable reading';

  @override
  String get comingNextPhase => 'This page is under construction';

  @override
  String get clearHistory => 'Clear history';
}

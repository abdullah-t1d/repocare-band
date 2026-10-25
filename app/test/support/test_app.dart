import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/app.dart';
import 'package:repocare_band/core/router/app_routes.dart';
import 'package:repocare_band/core/settings/app_settings.dart';
import 'package:repocare_band/features/band/data/transport/band_transport.dart';
import 'package:repocare_band/features/band/data/transport/demo_replay_transport.dart';
import 'package:repocare_band/features/band/data/transport/transport_factory.dart';
import 'package:repocare_band/features/band/presentation/providers/band_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Laptop size used on demo day.
const Size laptop = Size(1366, 900);

/// Starts the whole app with test doubles and returns its container.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required TransportFactory transports,
  Map<String, Object> prefs = const {},
  String initialLocation = AppRoutes.devices,
  Size size = laptop,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        transportFactoryProvider.overrideWithValue(transports),
      ],
      child: RepoCareApp(initialLocation: initialLocation),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(RepoCareApp)));
}

/// Stops all transports and unmounts the app so no timer is left running.
Future<void> tearDownApp(WidgetTester tester, ProviderContainer container) async {
  await container.read(connectionControllerProvider.notifier).disconnect();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Real demo transports, with the recordings read from disk up front (file
/// I/O does not complete inside the fake-async zone of widget tests).
class PreloadedDemoFactory implements TransportFactory {
  PreloadedDemoFactory._(this._files);

  static Future<PreloadedDemoFactory> load() async {
    final files = <String, String>{};
    for (final f in Directory('assets/recordings').listSync().whereType<File>()) {
      files['assets/recordings/${f.uri.pathSegments.last}'] = await f.readAsString();
    }
    return PreloadedDemoFactory._(files);
  }

  final Map<String, String> _files;

  @override
  bool get isUsbSerialSupported => false;

  @override
  BandTransport create(TransportRequest request) => switch (request) {
        DemoRequest(:final recording) => DemoReplayTransport(
            recording: recording,
            loadAsset: (key) async => _files[key]!,
          ),
        _ => throw UnsupportedError('Only demo transports in this test'),
      };
}

/// Pumps [duration] of app time in small steps so periodic timers and
/// animations run as they would in the browser.
Future<void> pumpFor(WidgetTester tester, Duration duration,
    {Duration step = const Duration(milliseconds: 100)}) async {
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repocare_band/core/settings/app_settings.dart';
import 'package:repocare_band/core/widgets/header_actions.dart';
import 'package:repocare_band/features/band/presentation/pages/devices_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_transport.dart';
import '../support/test_app.dart';

TextDirection _direction(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(DevicesPage)));

void main() {
  testWidgets('Arabic by default: right to left', (tester) async {
    final c = await pumpApp(tester, transports: FakeTransportFactory());
    expect(_direction(tester), TextDirection.rtl);
    expect(find.text('الأجهزة'), findsWidgets);
    expect(find.text('نموذج أولي لمشروع تخرج، غير تشخيصي'), findsOneWidget);
    await tearDownApp(tester, c);
  });

  testWidgets('switching to English mirrors the layout and is remembered', (tester) async {
    final c = await pumpApp(tester, transports: FakeTransportFactory());
    await tester.tap(find.byKey(LanguageToggle.englishKey));
    await tester.pumpAndSettle();

    expect(_direction(tester), TextDirection.ltr);
    expect(find.text('Devices'), findsWidgets);
    expect(find.text('Graduation project prototype, non-diagnostic'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SettingsController.localeKey), 'en');

    // Navigation rail moves to the other side.
    final railX = tester.getCenter(find.byType(NavigationRail)).dx;
    expect(railX, lessThan(laptop.width / 2), reason: 'LTR: rail on the left');

    await tester.tap(find.byKey(LanguageToggle.arabicKey));
    await tester.pumpAndSettle();
    expect(_direction(tester), TextDirection.rtl);
    expect(tester.getCenter(find.byType(NavigationRail)).dx, greaterThan(laptop.width / 2));
    expect(prefs.getString(SettingsController.localeKey), 'ar');
    await tearDownApp(tester, c);
  });

  testWidgets('a saved English choice is used on start', (tester) async {
    final c = await pumpApp(
      tester,
      transports: FakeTransportFactory(),
      prefs: {SettingsController.localeKey: 'en'},
    );
    expect(_direction(tester), TextDirection.ltr);
    expect(find.text('Connect your band'), findsOneWidget);
    await tearDownApp(tester, c);
  });

  testWidgets('dark mode toggle is applied and remembered', (tester) async {
    final c = await pumpApp(tester, transports: FakeTransportFactory());
    BuildContext ctx() => tester.element(find.byType(DevicesPage));
    expect(Theme.of(ctx()).brightness, Brightness.light);

    await tester.tap(find.byKey(ThemeToggle.buttonKey));
    await tester.pumpAndSettle();
    expect(Theme.of(ctx()).brightness, Brightness.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SettingsController.themeKey), 'dark');
    await tearDownApp(tester, c);
  });

  testWidgets('numbers use Western digits in Arabic', (tester) async {
    final c = await pumpApp(tester, transports: FakeTransportFactory());
    // The USB steps are numbered 1, 2, 3.
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining(RegExp('[٠-٩]')), findsNothing);
    await tearDownApp(tester, c);
  });
}

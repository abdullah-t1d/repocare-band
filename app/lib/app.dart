import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n/l10n.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/band/presentation/pages/placeholder_page.dart';

/// Routes of the app. Each page has its own URL so it can be bookmarked.
abstract final class AppRoutes {
  static const String devices = '/devices';
  static const String live = '/live';
  static const String measure = '/measure';
}

final List<AppDestination> _destinations = [
  AppDestination(
    path: AppRoutes.devices,
    icon: Icons.watch_outlined,
    selectedIcon: Icons.watch,
    label: (l10n) => l10n.navDevices,
  ),
  AppDestination(
    path: AppRoutes.live,
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart,
    label: (l10n) => l10n.navLive,
  ),
  AppDestination(
    path: AppRoutes.measure,
    icon: Icons.timer_outlined,
    selectedIcon: Icons.timer,
    label: (l10n) => l10n.navMeasure,
  ),
];

GoRouter buildRouter() => GoRouter(
      initialLocation: AppRoutes.devices,
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            final path = state.uri.path;
            final index = _destinations.indexWhere((d) => path.startsWith(d.path));
            return AppShell(
              destinations: _destinations,
              selectedIndex: index < 0 ? 0 : index,
              onSelect: (i) => context.go(_destinations[i].path),
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: AppRoutes.devices,
              pageBuilder: (context, state) => NoTransitionPage(
                child: PlaceholderPage(title: context.l10n.navDevices),
              ),
            ),
            GoRoute(
              path: AppRoutes.live,
              pageBuilder: (context, state) => NoTransitionPage(
                child: PlaceholderPage(title: context.l10n.navLive),
              ),
            ),
            GoRoute(
              path: AppRoutes.measure,
              pageBuilder: (context, state) => NoTransitionPage(
                child: PlaceholderPage(title: context.l10n.navMeasure),
              ),
            ),
          ],
        ),
      ],
    );

class RepoCareApp extends StatefulWidget {
  const RepoCareApp({super.key});

  @override
  State<RepoCareApp> createState() => _RepoCareAppState();
}

class _RepoCareAppState extends State<RepoCareApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}

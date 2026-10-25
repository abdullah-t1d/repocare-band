import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n/l10n.dart';
import 'core/router/app_routes.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/header_actions.dart';
import 'features/band/presentation/pages/devices_page.dart';
import 'features/band/presentation/pages/live_page.dart';
import 'features/band/presentation/pages/placeholder_page.dart';
import 'features/band/presentation/providers/live_controller.dart';
import 'features/band/presentation/widgets/connection_widgets.dart';

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

GoRouter buildRouter({String initialLocation = AppRoutes.devices}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            final path = state.uri.path;
            final index = _destinations.indexWhere((d) => path.startsWith(d.path));
            return LayoutBuilder(
              builder: (context, c) => AppShell(
                destinations: _destinations,
                selectedIndex: index < 0 ? 0 : index,
                onSelect: (i) => context.go(_destinations[i].path),
                headerActions: [
                  ConnectionStatusChip(compact: c.maxWidth < 640),
                  const LanguageToggle(),
                  const ThemeToggle(),
                ],
                banner: const ConnectionBanner(),
                child: child,
              ),
            );
          },
          routes: [
            GoRoute(
              path: AppRoutes.devices,
              pageBuilder: (context, state) => const NoTransitionPage(child: DevicesPage()),
            ),
            GoRoute(
              path: AppRoutes.live,
              pageBuilder: (context, state) => const NoTransitionPage(child: LivePage()),
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

class RepoCareApp extends ConsumerStatefulWidget {
  const RepoCareApp({this.initialLocation = AppRoutes.devices, super.key});

  final String initialLocation;

  @override
  ConsumerState<RepoCareApp> createState() => _RepoCareAppState();
}

class _RepoCareAppState extends ConsumerState<RepoCareApp> {
  late final GoRouter _router = buildRouter(initialLocation: widget.initialLocation);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Start listening to the band right away, whichever page is open first,
    // so no early line (e.g. #MODE) is missed.
    ref.listen(liveControllerProvider, (_, __) {});
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(brightness: Brightness.light, locale: settings.locale),
      darkTheme: AppTheme.build(brightness: Brightness.dark, locale: settings.locale),
      themeMode: settings.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 400),
      locale: settings.locale,
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

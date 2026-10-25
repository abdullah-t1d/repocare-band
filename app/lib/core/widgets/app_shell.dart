import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_palette.dart';

/// One entry of the main navigation.
class AppDestination {
  const AppDestination({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l10n) label;
}

/// Frame around every page: brand header, navigation (side rail on wide
/// screens, bottom bar on narrow ones), an optional banner area and the
/// non-diagnostic footer.
///
/// The layout uses directional widgets only, so it mirrors automatically
/// between Arabic (RTL) and English (LTR).
class AppShell extends StatelessWidget {
  const AppShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.child,
    this.headerActions = const [],
    this.banner,
    super.key,
  });

  /// Below this width the navigation moves to the bottom.
  static const double railBreakpoint = 900;

  /// Content never grows wider than this.
  static const double maxContentWidth = 1180;

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget child;

  /// Shown at the end of the header (status, language, theme).
  final List<Widget> headerActions;

  /// Shown between the header and the page, e.g. connection problems.
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= railBreakpoint;

    final body = Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                children: [
                  _Header(actions: headerActions, showSubtitle: width >= 640),
                  if (banner != null) banner!,
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
        const _Footer(),
      ],
    );

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelect,
                labelType: NavigationRailLabelType.all,
                minWidth: 96,
                groupAlignment: -0.85,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Icon(Icons.favorite, color: context.palette.pulse, size: 28),
                ),
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: SizedBox(
                        width: 84,
                        child: Text(d.label(l10n), textAlign: TextAlign.center, maxLines: 2),
                      ),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelect,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label(l10n),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.actions, required this.showSubtitle});

  final List<Widget> actions;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appTitle, style: theme.textTheme.titleLarge, textDirection: TextDirection.ltr),
                if (showSubtitle)
                  Text(l10n.appSubtitle,
                      style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          for (final a in actions) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: a),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.palette.rule))),
      child: Text(
        context.l10n.footerDisclaimer,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

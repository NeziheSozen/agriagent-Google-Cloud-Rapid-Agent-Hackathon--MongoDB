import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/l10n/translations.dart';
import '../app/responsive.dart';
import '../app/theme.dart';

/// Destination definition for navigation.
class NavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;

  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });
}

/// The primary navigation destinations.
List<NavDestination> _getDestinations(BuildContext context) => [
  NavDestination(
    label: L10n.tr(context, 'nav_dashboard'),
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    path: '/',
  ),
  NavDestination(
    label: L10n.tr(context, 'nav_climate'),
    icon: Icons.thermostat_outlined,
    selectedIcon: Icons.thermostat_rounded,
    path: '/climate',
  ),
  NavDestination(
    label: L10n.tr(context, 'nav_threats'),
    icon: Icons.warning_amber_rounded,
    selectedIcon: Icons.warning_rounded,
    path: '/threats',
  ),
  NavDestination(
    label: L10n.tr(context, 'nav_market'),
    icon: Icons.attach_money_rounded,
    selectedIcon: Icons.monetization_on_rounded,
    path: '/market',
  ),
];

/// Adaptive responsive scaffold.
///
/// - **Mobile** (<600): BottomNavigationBar
/// - **Tablet** (600-1200): NavigationRail
/// - **Desktop** (>1200): Permanent NavigationDrawer (240px)
class ResponsiveScaffold extends StatelessWidget {
  final Widget child;

  const ResponsiveScaffold({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final destinations = _getDestinations(context);
    for (int i = 0; i < destinations.length; i++) {
      if (destinations[i].path == location) return i;
    }
    // Check for sub-routes
    if (location.startsWith('/report')) return 0;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    context.go(_getDestinations(context)[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    if (context.isMobile) {
      return _MobileScaffold(
        currentIndex: currentIndex,
        onDestinationSelected: (i) => _onDestinationSelected(context, i),
        child: child,
      );
    }

    if (context.isTablet) {
      return _TabletScaffold(
        currentIndex: currentIndex,
        onDestinationSelected: (i) => _onDestinationSelected(context, i),
        child: child,
      );
    }

    return _DesktopScaffold(
      currentIndex: currentIndex,
      onDestinationSelected: (i) => _onDestinationSelected(context, i),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE — BottomNavigationBar
// ─────────────────────────────────────────────────────────────────────────────
class _MobileScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  const _MobileScaffold({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onDestinationSelected,
          items: _getDestinations(context).map((d) {
            return BottomNavigationBarItem(
              icon: Icon(d.icon),
              activeIcon: Icon(d.selectedIcon),
              label: d.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET — NavigationRail
// ─────────────────────────────────────────────────────────────────────────────
class _TabletScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  const _TabletScaffold({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            extended: false,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _AgriLogo(compact: true),
            ),
            destinations: _getDestinations(context).map((d) {
              return NavigationRailDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: Text(d.label),
              );
            }).toList(),
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: Colors.white.withOpacity(0.06),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP — Permanent NavigationDrawer
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  const _DesktopScaffold({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Permanent drawer
          SizedBox(
            width: 240,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Logo header
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: _AgriLogo(compact: false),
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    color: Colors.white.withOpacity(0.06),
                    height: 1,
                  ),
                  const SizedBox(height: 8),

                  // Destinations
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      itemCount: _getDestinations(context).length,
                      itemBuilder: (context, index) {
                        final dest = _getDestinations(context)[index];
                        final isSelected = index == currentIndex;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => onDestinationSelected(index),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AgriAgentTheme.mossGreen
                                          .withOpacity(0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? dest.selectedIcon
                                          : dest.icon,
                                      color: isSelected
                                          ? AgriAgentTheme.mossGreen
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      dest.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AgriAgentTheme.mossGreen
                                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AgriAgentTheme.successGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          L10n.tr(context, 'api_connected'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo
// ─────────────────────────────────────────────────────────────────────────────
class _AgriLogo extends StatelessWidget {
  final bool compact;

  const _AgriLogo({required this.compact});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AgriAgentTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.eco_rounded,
          color: Colors.white,
          size: 24,
        ),
      );
    }

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: AgriAgentTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AgriAgentTheme.mossGreen.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.eco_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AgriAgent',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
            ),
            Text(
              L10n.tr(context, 'predictive_advisor'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AgriAgentTheme.mossGreen.withOpacity(0.7),
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../screens/home_screen.dart';
import '../screens/farmer_screen.dart';
import '../screens/profile_edit_screen.dart';
import '../screens/climate_screen.dart';
import '../screens/threats_screen.dart';
import '../screens/market_screen.dart';
import '../screens/report_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/chatbot_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/offline_setup_screen.dart';
import '../screens/cooperatives_screen.dart';
import '../screens/logistics_screen.dart';
import '../widgets/responsive_scaffold.dart';

/// AgriAgent root application widget.
///
/// Configures MaterialApp.router with GoRouter, theme, and
/// the responsive scaffold shell route.
class AgriAgentApp extends ConsumerWidget {
  final String initialLocation;
  const AgriAgentApp({super.key, this.initialLocation = '/login'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'AgriAgent - Predictive Farming Advisor',
      debugShowCheckedModeBanner: false,
      theme: AgriAgentTheme.light(),
      darkTheme: AgriAgentTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('tr'),
        Locale('nl'),
        Locale('es'),
        Locale('it'),
        Locale('ja'),
        Locale('ko'),
        Locale('fr'),
        Locale('pt'),
        Locale('hi'),
        Locale('zh'),
      ],
      routerConfig: createRouter(initialLocation),
    );
  }
}

/// GoRouter configuration with shell route for persistent navigation.
GoRouter createRouter(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatbotScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/offline-setup',
      builder: (context, state) => const OfflineSetupScreen(),
    ),
    // Shell route wraps all screens with ResponsiveScaffold
    ShellRoute(
      builder: (context, state, child) {
        return ResponsiveScaffold(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => _fadeTransitionPage(
            key: state.pageKey,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/farmer',
          pageBuilder: (context, state) => _fadeTransitionPage(
            key: state.pageKey,
            child: const FarmerScreen(),
          ),
        ),
        GoRoute(
          path: '/profile/edit',
          pageBuilder: (context, state) => _fadeTransitionPage(
            key: state.pageKey,
            child: const ProfileEditScreen(),
          ),
        ),
        GoRoute(
          path: '/climate',
          pageBuilder: (context, state) => _fadeTransitionPage(
            key: state.pageKey,
            child: const ClimateScreen(),
          ),
        ),
        GoRoute(
          path: '/threats',
          pageBuilder: (context, state) => _fadeTransitionPage(
            key: state.pageKey,
            child: const ThreatsScreen(),
          ),
        ),
        GoRoute(
          path: '/market',
          pageBuilder: (context, state) => _fadeTransitionPage(
            key: state.pageKey,
            child: const MarketScreen(),
          ),
        ),
        GoRoute(
          path: '/cooperatives',
          pageBuilder: (context, state) => _fadeTransitionPage(
            key: state.pageKey,
            child: const CooperativesScreen(),
          ),
        ),
        GoRoute(
          path: '/logistics',
          pageBuilder: (context, state) => _fadeTransitionPage(
            key: state.pageKey,
            child: const LogisticsScreen(),
          ),
        ),
        GoRoute(
          path: '/report',
          pageBuilder: (context, state) => _fadeTransitionPage(
            key: state.pageKey,
            child: const ReportScreen(),
          ),
        ),
      ],
    ),
  ],
);

/// Custom fade + slide transition for smooth screen navigation.
CustomTransitionPage<void> _fadeTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).animate(fadeAnimation);

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: child,
        ),
      );
    },
  );
}

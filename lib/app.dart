import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/auth_provider.dart';
import 'features/auth/presentation/pages/login_screen.dart';
import 'features/auth/presentation/pages/signup_screen.dart';
import 'shared/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/food_scan/presentation/pages/robust_food_scan_screen.dart';
import 'features/kinematic/presentation/pages/robust_kinematic_screen.dart';
import 'features/bio_twin/presentation/pages/robust_bio_twin_screen.dart';
import 'features/causal_insights/presentation/pages/robust_causal_screen.dart';
import 'features/aeg_graph/presentation/pages/robust_aeg_screen.dart';
import 'features/bio_arbitrage/bio_arbitrage_screen.dart';
import 'features/epigenomic_diff/epigenomic_screen.dart';
import 'features/nutrigenomics/insights_screen.dart';
import 'features/genomics/presentation/pages/genomics_dashboard_screen.dart';
import 'shared/presentation/unicorn_score_screen.dart';
import 'shared/presentation/dynamic_unicorn_screen.dart';

import 'shared/presentation/main_scaffold.dart';
import 'features/sleep/presentation/pages/sleep_dashboard_screen.dart';
import 'features/discover/presentation/pages/discover_screen.dart';
import 'features/home/presentation/pages/home_screen.dart';
import 'features/discover/presentation/pages/manual_dna_input_screen.dart';
import 'features/discover/presentation/pages/manual_sleep_input_screen.dart';
import 'features/coach/presentation/pages/health_agent_notifications_screen.dart';
import 'features/coach/presentation/pages/health_agent_chat_screen.dart';
import 'features/home/presentation/pages/home_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final GlobalKey<NavigatorState> _nutritionNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'nutrition');
final GlobalKey<NavigatorState> _sleepNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'sleep');
final GlobalKey<NavigatorState> _activityNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'activity');
final GlobalKey<NavigatorState> _discoverNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'discover');

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuth = authState.valueOrNull != null;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      if (authState.isLoading) return null; // Wait for initial load

      if (!isAuth && !isLoggingIn) return '/login';
      if (isAuth && isLoggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
      branches: [
        StatefulShellBranch(
          navigatorKey: _homeNavigatorKey,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _nutritionNavigatorKey,
          routes: [
            GoRoute(
              path: '/nutrition',
              builder: (context, state) => const RobustFoodScanScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _sleepNavigatorKey,
          routes: [
            GoRoute(
              path: '/sleep',
              builder: (context, state) => const DynamicUnicornScreen(
                domain: 'sleep',
                loadingTitle: 'Sleep Optimization',
                themeColor: Colors.deepPurpleAccent,
                icon: Icons.nights_stay,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _activityNavigatorKey,
          routes: [
            GoRoute(
              path: '/activity',
              builder: (context, state) => const DynamicUnicornScreen(
                domain: 'activity',
                loadingTitle: 'Activity & Kinematics',
                themeColor: Colors.orangeAccent,
                icon: Icons.directions_run,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _discoverNavigatorKey,
          routes: [
            GoRoute(
              path: '/discover',
              builder: (context, state) => const DiscoverScreen(),
            ),
          ],
        ),
      ],
    ),
    // Hidden / advanced routes
    // Advanced / Marketplace Routes
    GoRoute(path: '/discover/bio-twin', builder: (context, state) => const RobustBioTwinScreen()),
    GoRoute(path: '/discover/causal', builder: (context, state) => const RobustCausalScreen()),
    
    // New Unicorn Simple Screens
    GoRoute(
      path: '/discover/aeg',
      builder: (context, state) => const DynamicUnicornScreen(
        domain: 'aeg',
        loadingTitle: 'Aging Clock',
        themeColor: Colors.orangeAccent,
        icon: Icons.access_time,
      ),
    ),
    GoRoute(
      path: '/discover/dna',
      builder: (context, state) => const DynamicUnicornScreen(
        domain: 'dna',
        loadingTitle: 'My DNA Insights',
        themeColor: Colors.tealAccent,
        icon: Icons.biotech,
      ),
    ),
    GoRoute(
      path: '/discover/gut',
      builder: (context, state) => const DynamicUnicornScreen(
        domain: 'gut',
        loadingTitle: 'Gut Health',
        themeColor: Colors.greenAccent,
        icon: Icons.eco,
      ),
    ),
    GoRoute(
      path: '/discover/blood',
      builder: (context, state) => const DynamicUnicornScreen(
        domain: 'blood',
        loadingTitle: 'Blood & Hormones',
        themeColor: Colors.redAccent,
        icon: Icons.water_drop,
      ),
    ),
    GoRoute(
      path: '/discover/speedometer',
      builder: (context, state) => const DynamicUnicornScreen(
        domain: 'speedometer',
        loadingTitle: 'Aging Speedometer',
        themeColor: Colors.yellowAccent,
        icon: Icons.speed,
      ),
    ),
    GoRoute(
      path: '/discover/dna/input',
      builder: (context, state) => const ManualDnaInputScreen(),
    ),
    GoRoute(
      path: '/discover/sleep/input',
      builder: (context, state) => const ManualSleepInputScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const HealthAgentNotificationsScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        return HealthAgentChatScreen(initialAlertData: state.extra);
      },
    ),
    GoRoute(
      path: '/discover/circle',
      builder: (context, state) => const DynamicUnicornScreen(
        domain: 'circle',
        loadingTitle: 'Health Circle',
        themeColor: Colors.indigoAccent,
        icon: Icons.group,
      ),
    ),
    GoRoute(
      path: '/discover/wearables',
      builder: (context, state) => const DynamicUnicornScreen(
        domain: 'wearables',
        loadingTitle: 'Wearable Telemetry',
        themeColor: Colors.cyanAccent,
        icon: Icons.watch,
      ),
    ),
    GoRoute(
      path: '/discover/arbitrage',
      builder: (context, state) => const DynamicUnicornScreen(
        domain: 'arbitrage',
        loadingTitle: 'Bio-Arbitrage',
        themeColor: Colors.pinkAccent,
        icon: Icons.attach_money,
      ),
    ),
    GoRoute(
      path: '/discover/nutrigenomics',
      builder: (context, state) => const DynamicUnicornScreen(
        domain: 'nutrigenomics',
        loadingTitle: 'Gene-Diet Fit',
        themeColor: Colors.purpleAccent,
        icon: Icons.science,
      ),
    ),
  ],
);

});

class App extends ConsumerWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Welloa',
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

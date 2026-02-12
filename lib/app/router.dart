import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/wissen/wissen_screen.dart';
import '../features/innen/innen_screen.dart';
import '../features/identitaet/identitaet_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profil/profil_screen.dart';
import '../features/system/system_screen.dart';
import '../features/snacks/snacks_list_screen.dart';
import 'shell_scaffold.dart';

final appRouter = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => ShellScaffold(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/wissen',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WissenScreen()),
        ),
        GoRoute(
          path: '/innen',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: InnenScreen()),
        ),
        GoRoute(
          path: '/identitaet',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: IdentitaetScreen()),
        ),
        GoRoute(
          path: '/system',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SystemScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/profil',
      builder: (context, state) => const ProfilScreen(),
    ),
    GoRoute(
      path: '/snacks',
      builder: (context, state) => const SnacksListScreen(),
    ),
  ],
);

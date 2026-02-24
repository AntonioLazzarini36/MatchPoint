import 'package:go_router/go_router.dart';

import 'package:match_point/app/routes.dart';
import 'package:match_point/core/auth/auth_gate.dart';

// Screens
import 'package:match_point/features/welcome/screens/welcome_screen.dart';
import 'package:match_point/features/auth/screens/onboarding_auth_screen.dart';
import 'package:match_point/features/onboarding/screens/onboarding_profile_screen.dart';

import 'package:match_point/features/discovery/screens/discovery_screen.dart';
import 'package:match_point/features/discovery/screens/partner_detail_screen.dart';
import 'package:match_point/features/matches/models/match_item.dart';
import 'package:match_point/features/matches/screens/matches_screen.dart';
import 'package:match_point/features/matches/screens/chat_screen.dart';

import 'package:match_point/features/profile/screens/profile_screen.dart';
import 'package:match_point/features/profile/screens/settings_screen.dart';

import 'package:match_point/core/ui/widgets/navigator.dart'; // o tu path real

final _authGate = AuthGate();

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.welcome,
    routes: [
      // --- AUTH / ONBOARDING ---
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingAuth,
        builder: (context, state) => const OnboardingAuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingProfileScreen(),
      ),

      // --- MAIN APP ---
      GoRoute(
        path: AppRoutes.discovery,
        builder: (context, state) => const DiscoveryScreen(),
      ),
      GoRoute(
        path: AppRoutes.partnerDetail,
        builder: (context, state) => const PartnerDetailScreen(),
      ),

      // --- MATCHES ---
      GoRoute(
        path: AppRoutes.matches,
        builder: (context, state) => const MatchesScreen(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) {
          final matchId = state.pathParameters['matchId']!;
          final match = state.extra as MatchItem; // lo pasamos desde MatchesScreen

          return ChatScreen(
            matchId: matchId,
            myUserId: match.me.userId,
            otherName: match.otherUser.profile?.displayName ?? 'Sin nombre',
          );
        },
      ),

      // --- PROFILE ---
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.shell,
        builder: (context, state) => const NavigatorShell(),
      ),
    ],
    redirect: (context, state) async {
      final loggedIn = await _authGate.isLoggedIn();
      final loc = state.matchedLocation;

      final isPublicRoute =
          loc == AppRoutes.welcome || loc == AppRoutes.onboardingAuth;

      // 🚫 No loggeado intentando entrar a algo privado
      if (!loggedIn && !isPublicRoute) {
        return AppRoutes.onboardingAuth;
      }

      // ✅ Ya loggeado intentando ir a login o welcome
      if (loggedIn && isPublicRoute) {
        return AppRoutes.shell;
      }

      return null;
    },
  );
}

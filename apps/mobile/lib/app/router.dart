import 'package:go_router/go_router.dart';

import 'package:match_point/app/routes.dart';
import 'package:match_point/core/auth/auth_gate.dart';

// Screens
import 'package:match_point/features/welcome/screens/welcome_screen.dart';
import 'package:match_point/features/auth/models/register_request.dart';
import 'package:match_point/features/auth/screens/onboarding_auth_screen.dart';
import 'package:match_point/features/onboarding/screens/onboarding_profile_screen.dart';

import 'package:match_point/features/discovery/screens/discovery_screen.dart';
import 'package:match_point/features/discovery/screens/partner_detail_screen.dart';
import 'package:match_point/features/matches/models/match_item.dart';
import 'package:match_point/features/matches/screens/matches_screen.dart';
import 'package:match_point/features/matches/screens/chat_screen.dart';
import 'package:match_point/features/courts/screens/tennis_courts_map_screen.dart';
import 'package:match_point/features/profile/screens/other_profile_screen.dart';
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
        builder: (context, state) {
          // El registro (email+password) todavía no ha pasado cuando se
          // entra aquí desde OnboardingAuthScreen — se completa entero
          // (usuario+perfil+foto) al terminar el wizard. `extra` es null
          // cuando se llega aquí por el redirect de "cuenta a medias"
          // (ver abajo): en ese caso ya hay token, solo falta completar
          // el perfil, no registrar de nuevo.
          final draft = state.extra as RegisterRequest?;
          return OnboardingProfileScreen(
            email: draft?.email,
            password: draft?.password,
          );
        },
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
          final match =
              state.extra as MatchItem; // lo pasamos desde MatchesScreen

          final otherPhotos = match.otherUser.profile?.photos ?? const [];

          return ChatScreen(
            matchId: matchId,
            myUserId: match.me.userId,
            otherUserId: match.otherUser.userId,
            otherName: match.otherUser.profile?.displayName ?? 'Sin nombre',
            otherPhotoUrl: otherPhotos.isNotEmpty ? otherPhotos.first : null,
            sport: match.sport,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.courtsMap,
        builder: (context, state) => const TennisCourtsMapScreen(),
      ),

      // --- PROFILE ---
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
      path: AppRoutes.userProfile,
      name: AppRoutes.userProfileName,
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return OtherProfileScreen(userId: userId);
      },
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
      // El registro se completa al final del wizard, así que /onboarding
      // tiene que poder visitarse sin estar logueado todavía.
      final isOnboardingRoute = loc == AppRoutes.onboarding;

      // 🚫 No loggeado intentando entrar a algo privado (y que no sea el
      // propio onboarding, que es el único sitio pensado para eso)
      if (!loggedIn && !isPublicRoute && !isOnboardingRoute) {
        return AppRoutes.onboardingAuth;
      }

      // ✅ Ya loggeado intentando ir a login o welcome
      if (loggedIn && isPublicRoute) {
        return AppRoutes.shell;
      }

      // 🚧 Logueado pero con una cuenta a medias (de un intento de
      // onboarding interrumpido) intentando entrar a cualquier otra
      // pantalla privada — de vuelta al onboarding hasta completarlo.
      if (loggedIn && !isOnboardingRoute) {
        final complete = await _authGate.hasCompleteProfile();
        if (!complete) return AppRoutes.onboarding;
      }

      return null;
    },
  );
}

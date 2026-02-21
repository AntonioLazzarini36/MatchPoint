import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/welcome/screens/welcome_screen.dart';
import 'routes.dart';
import '../core/ui/widgets/navigator.dart';
import '../features/auth/screens/onboarding/onboarding_profile_screen.dart';
import '../features/auth/screens/discovery/partner_detail_screen.dart';
import '../features/auth/screens/matches/chat_screen.dart';
import '../features/auth/screens/profile/settings_screen.dart';

class MatchPointApp extends StatelessWidget {
  const MatchPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MatchPoint',
      theme: AppTheme.dark(),
      initialRoute: AppRoutes.welcome,
      routes: {
        AppRoutes.welcome: (_) => const WelcomeScreen(),
        AppRoutes.onboardingProfile: (_) => const OnboardingProfileScreen(),
        AppRoutes.shell: (_) => const NavigatorShell(),
        AppRoutes.partnerDetail: (_) => const PartnerDetailScreen(),
        AppRoutes.chat: (_) => const ChatScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
      },
    );
  }
}

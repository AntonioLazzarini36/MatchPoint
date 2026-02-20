import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../screens/welcome/welcome_screen.dart';
import 'routes.dart';
import '../widgets/navigator.dart';
import '../screens/onboarding/onboarding_profile_screen.dart';
import '../screens/discovery/partner_detail_screen.dart';
import '../screens/matches/chat_screen.dart';
import '../screens/profile/settings_screen.dart';

class MatchPointApp extends StatelessWidget {
  const MatchPointApp({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MatchPoint',
      theme: AppTheme.light(),
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
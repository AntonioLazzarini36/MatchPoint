class AppRoutes {
  // Auth / onboarding
  static const welcome = '/welcome';
  static const onboardingAuth = '/onboarding-auth';
  static const onboarding = '/onboarding';
  static const shell = '/shell';

  // Main app
  static const discovery = '/discovery';
  static const partnerDetail = '/partner';

  // Matches / chat
  static const matches = '/matches';
  static const chat = '/chat/:matchId';
  static const courtsMap = '/courts-map';

  // Profile / settings
  static const profile = '/profile';
  static const userProfile = '/u/:userId';
  static const userProfileName = 'userProfile';
  static const settings = '/settings';
}

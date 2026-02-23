import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import './router.dart';

class MatchPointApp extends StatelessWidget {
  const MatchPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MatchPoint',
      theme: lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}

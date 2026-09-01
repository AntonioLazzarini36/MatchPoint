import 'package:flutter/material.dart';
import '../core/i18n/app_locale.dart';
import '../core/theme/app_theme.dart';
import './router.dart';

class MatchPointApp extends StatelessWidget {
  const MatchPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    // El `ValueListenableBuilder` envuelve el `MaterialApp` entero: cambiar de
    // idioma tiene que repintar toda la app, no sólo la pantalla donde está el
    // selector. Sin esto habría que cerrar y volver a abrir para verlo, que es
    // exactamente lo que hace que nadie use un selector de idioma.
    return ValueListenableBuilder<AppLocale>(
      valueListenable: LocaleController.locale,
      builder: (context, locale, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'MatchPoint',
          theme: lightTheme,
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}

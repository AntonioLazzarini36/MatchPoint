import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/ui/widgets/app_logo.dart';
import '../../../core/ui/widgets/background_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return BackgroundScaffold(
      assetPath: 'assets/images/welcome.jpg',
      // Los dos `Spacer` reparten el hueco sobrante cuando lo hay, pero no
      // pueden encogerse por debajo de cero: en pantallas cortas el
      // contenido fijo (logo + textos + tres botones) no cabía y esto
      // desbordaba 82 px. Con el scroll y un alto mínimo igual al
      // viewport, se sigue viendo centrado donde cabe y se puede
      // desplazar donde no.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Center(child: AppLogo(size: 88)),
                  const SizedBox(height: 20),
                  Text(
                    'MatchPoint',
                    textAlign: TextAlign.center,
                    style: t.headlineLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Encuentra con quién jugar\na tu nivel, cerca de ti.',
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(color: Colors.white70),
                  ),
                  const Spacer(),

                  // Aquí había además dos botones desactivados, "Google
                  // (próximamente)" y "Apple (próximamente)". Prometían algo
                  // que no existe y que depende de credenciales externas
                  // (Google Cloud Console, cuenta de Apple Developer), así
                  // que la primera pantalla de la app anunciaba una función
                  // que nadie puede usar. Vuelven cuando funcionen.
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.onboardingAuth),
                    child: const Text('Empezar'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

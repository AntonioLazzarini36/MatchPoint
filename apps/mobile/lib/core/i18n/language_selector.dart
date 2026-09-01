import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_locale.dart';

/// Elegir idioma sin una sola palabra.
///
/// **No lleva etiqueta ("Idioma" / "Language") a propósito.** Esa palabra es
/// justo la que no puede leer quien la necesita: alguien con la app en un
/// idioma que no habla. Un globo terráqueo y una bandera se entienden sin
/// saber leer nada, y ocupan una fracción.
///
/// Funciona como un interruptor: al tocarlo **el globo se desliza al otro
/// lado y la bandera aparece donde estaba el globo**. Los dos se cruzan, así
/// que el movimiento cuenta lo que ha pasado — no hace falta explicarlo. Y en
/// reposo sólo se ve una bandera, la del idioma activo: enseñar las dos
/// obligaría a averiguar cuál está puesta.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key, this.compact = false});

  /// Versión pequeña, para una fila de ajustes.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLocale>(
      valueListenable: LocaleController.locale,
      builder: (context, current, _) {
        final other = AppLocale.values.firstWhere((l) => l != current);

        final height = compact ? 36.0 : 44.0;
        final width = height * 1.85;
        final knob = height - 6;
        // El castellano deja el globo a la derecha y el inglés a la
        // izquierda; da igual cuál sea cuál, lo que importa es que sean lados
        // opuestos y que siempre el mismo por idioma.
        final knobRight = current == AppLocale.es;

        return Semantics(
          button: true,
          // Lo único escrito de todo el control, y sólo lo oye quien usa
          // lector de pantalla: ahí una bandera sin texto no dice nada.
          label: '${current.label} → ${other.label}',
          child: Material(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(height),
            child: InkWell(
              borderRadius: BorderRadius.circular(height),
              onTap: () => LocaleController.set(other),
              child: SizedBox(
                width: width,
                height: height,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Stack(
                    children: [
                      // La bandera, en el lado contrario al globo. Se cruza
                      // con él: acaba justo donde el globo estaba.
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: knobRight
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: SizedBox(
                          width: knob,
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                current.flag,
                                key: ValueKey(current),
                                style: TextStyle(
                                  fontSize: compact ? 17 : 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // El globo, deslizándose de un lado al otro.
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: knobRight
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: knob,
                          height: knob,
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.language,
                            size: compact ? 18 : 22,
                            color: context.colors.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// El mismo control, como fila de Ajustes.
///
/// Sin la palabra "Idioma" tampoco aquí: el interruptor ya lleva el globo, y
/// la bandera visible contesta la única pregunta de esa fila.
class LanguageSettingsTile extends StatelessWidget {
  const LanguageSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.translate, color: context.colors.onSurfaceVariant),
          const Spacer(),
          const LanguageToggle(compact: true),
        ],
      ),
    );
  }
}

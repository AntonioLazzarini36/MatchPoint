import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'strings.dart';
import 'strings_en.dart';
import 'strings_es.dart';

/// Los idiomas que habla la app.
enum AppLocale {
  es('es', 'Español', '\u{1F1EA}\u{1F1F8}'),
  en('en', 'English', '\u{1F1EC}\u{1F1E7}');

  const AppLocale(this.code, this.label, this.flag);

  /// Código ISO, que es lo que se guarda en disco.
  final String code;

  /// Cómo se llama **en su propio idioma**. Nunca "Spanish" en la lista
  /// inglesa: quien busca su idioma en un selector busca la palabra que
  /// reconoce, y si ya está viendo la app en un idioma que no entiende,
  /// traducir los nombres es justo lo que le impide salir de ahí.
  ///
  /// Ya no se pinta en el selector (ahí va la bandera), pero se sigue
  /// usando donde hace falta una palabra: lo que lee un lector de
  /// pantalla.
  final String label;

  /// La bandera, como emoji.
  ///
  /// Emoji y no imágenes: Android e iOS las dibujan de serie, así que no
  /// hay assets que meter, ni versiones por densidad, ni nadie que se
  /// tenga que acordar de añadirlas el día que entre un tercer idioma.
  ///
  /// Escritas con escapes `\u{...}` a propósito: son pares de indicadores
  /// regionales y, pegadas literalmente, cualquier herramienta que
  /// reguarde el fichero con otra codificación las parte en dos letras —
  /// y entonces salen "ES" y "GB" en texto plano en vez de la bandera,
  /// sin que nada falle ni avise.
  final String flag;
}

/// Qué idioma se está usando, y cómo cambiarlo.
///
/// **No usa `flutter_localizations` ni ARB a propósito.** Esta app tiene texto
/// en sitios donde no hay `BuildContext`: los `label` de los enums
/// (`SkillLevel`, `Intention`, `Sport`), los mensajes de error de los
/// servicios, los nombres de los meses en `date_format_es.dart`. Con el
/// mecanismo oficial habría que arrastrar un contexto hasta ahí o duplicar
/// las cadenas, y las dos salidas son peores que un idioma global leído por
/// `S`.
///
/// Lo que sí se conserva del enfoque oficial es la garantía que importa: las
/// cadenas están declaradas en una clase abstracta (`Strings`), así que si se
/// añade un texto y falta su traducción **el proyecto no compila**. No hay
/// forma de que la app se quede a medio traducir sin que nadie se entere.
class LocaleController {
  LocaleController._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'app_locale';

  /// El idioma actual. Es un `ValueNotifier` para que el `MaterialApp` entero
  /// se reconstruya al cambiarlo — sin eso habría que reiniciar la app.
  static final ValueNotifier<AppLocale> locale = ValueNotifier(_deviceDefault());

  /// Lo que se ve en cualquier parte del código: `S.current.guardar`.
  static Strings get strings => switch (locale.value) {
    AppLocale.es => const StringsEs(),
    AppLocale.en => const StringsEn(),
  };

  /// El idioma del móvil, para la primera vez. Si no es español, inglés:
  /// para alguien cuyo teléfono está en alemán, el inglés es mucho mejor
  /// punto de partida que un castellano que no entiende.
  static AppLocale _deviceDefault() {
    final lang = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return lang == 'es' ? AppLocale.es : AppLocale.en;
  }

  /// Lee el idioma guardado. Se llama al arrancar, antes de `runApp`.
  ///
  /// Si falla la lectura se queda con el del dispositivo: quedarse sin
  /// preferencia guardada es un incordio, no abrir la app es otra cosa.
  static Future<void> load() async {
    try {
      final saved = await _storage.read(key: _key);
      final found = AppLocale.values.where((l) => l.code == saved);
      if (found.isNotEmpty) locale.value = found.first;
    } catch (e) {
      debugPrint('idioma: no se ha podido leer el guardado: $e');
    }
  }

  static Future<void> set(AppLocale value) async {
    locale.value = value;
    try {
      await _storage.write(key: _key, value: value.code);
    } catch (e) {
      debugPrint('idioma: no se ha podido guardar: $e');
    }
  }
}

/// Atajo para leer los textos: `S.current.entrar`.
class S {
  S._();
  static Strings get current => LocaleController.strings;
}

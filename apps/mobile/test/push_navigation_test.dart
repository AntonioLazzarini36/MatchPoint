import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/push/push_navigation.dart';

/// Los tipos de aviso los escribe el backend (`push::spawn_notify`) y esta
/// tabla es el único sitio donde se traducen a una pantalla. Si alguien añade
/// un tipo allí y no aquí, el aviso se vuelve un toque que no hace nada — un
/// fallo que no rompe ninguna compilación y que sólo se ve con el móvil en la
/// mano. De ahí que se pruebe uno por uno.
void main() {
  test('un mensaje abre su conversación', () {
    final d = PushNavigation.resolve({'type': 'message', 'matchId': 'm1'});
    expect(d.target, PushTarget.chat);
    expect(d.matchId, 'm1');
  });

  test('un match nuevo y una propuesta también abren el chat', () {
    for (final type in ['match', 'proposal']) {
      final d = PushNavigation.resolve({'type': type, 'matchId': 'm2'});
      expect(d.target, PushTarget.chat, reason: type);
      expect(d.matchId, 'm2', reason: type);
    }
  });

  test('recordatorio y "qué tal fue" llevan a Partidos', () {
    for (final type in ['reminder', 'feedback']) {
      expect(
        PushNavigation.resolve({'type': type, 'matchId': 'm3'}).target,
        PushTarget.upcoming,
        reason: type,
      );
    }
  });

  test('un tipo desconocido no lleva a ninguna parte, no revienta', () {
    expect(
      PushNavigation.resolve({'type': 'algo_del_futuro'}).target,
      PushTarget.none,
    );
    expect(PushNavigation.resolve(null).target, PushTarget.none);
    expect(PushNavigation.resolve(const {}).target, PushTarget.none);
  });

  test('un chat sin matchId no lleva a ninguna parte', () {
    // Preferible a abrir "/chat/null": una pantalla de error por un dato que
    // falta es peor que quedarse donde estabas.
    expect(PushNavigation.resolve({'type': 'message'}).target, PushTarget.none);
    expect(
      PushNavigation.resolve({'type': 'message', 'matchId': ''}).target,
      PushTarget.none,
    );
  });
}

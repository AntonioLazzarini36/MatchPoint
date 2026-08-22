import 'package:flutter/material.dart';

/// A qué viene la persona (`Profile.intention`).
///
/// Antes esto se preguntaba en el onboarding como "objetivo" y la frase
/// elegida **se guardaba como la bio**, así que en toda la app sólo existían
/// tres descripciones posibles y todos los perfiles se leían igual. Son dos
/// datos distintos: esto es estructurado —se enseña como etiqueta y algún día
/// se podrá filtrar por ello— y la bio vuelve a ser texto que escribe la
/// persona.
///
/// Declararlo es opcional: `null` es "no lo he dicho". Igual que `Gender`, el
/// backend distingue "campo omitido" de "campo mandado como null" para que se
/// pueda volver atrás tras haber elegido (ver `double_option` en
/// `services/api-rust/src/me/dto.rs`).
enum Intention { compete, train, learn, fun }

extension IntentionApi on Intention {
  String get apiValue {
    switch (this) {
      case Intention.compete:
        return 'COMPETE';
      case Intention.train:
        return 'TRAIN';
      case Intention.learn:
        return 'LEARN';
      case Intention.fun:
        return 'FUN';
    }
  }

  /// Texto corto, el que va en la etiqueta del perfil.
  String get label {
    switch (this) {
      case Intention.compete:
        return 'Competir';
      case Intention.train:
        return 'Entrenar';
      case Intention.learn:
        return 'Mejorar mi nivel';
      case Intention.fun:
        return 'Divertirme';
    }
  }

  /// Lo que aclara la diferencia al elegir. Sin esto, "competir" y
  /// "entrenar" se confunden.
  String get description {
    switch (this) {
      case Intention.compete:
        return 'Partidos serios, con marcador';
      case Intention.train:
        return 'Preparar una carrera o mantenerme en forma';
      case Intention.learn:
        return 'Busco a alguien mejor que me haga subir de nivel';
      case Intention.fun:
        return 'Sin presión, por el gusto de jugar';
    }
  }

  IconData get icon {
    switch (this) {
      case Intention.compete:
        return Icons.emoji_events_outlined;
      case Intention.train:
        return Icons.fitness_center;
      case Intention.learn:
        return Icons.trending_up;
      case Intention.fun:
        return Icons.sentiment_satisfied_alt;
    }
  }

  static Intention? fromApi(Object? v) {
    switch (v?.toString()) {
      case 'COMPETE':
        return Intention.compete;
      case 'TRAIN':
        return Intention.train;
      case 'LEARN':
        return Intention.learn;
      case 'FUN':
        return Intention.fun;
      default:
        return null;
    }
  }
}

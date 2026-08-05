import 'package:flutter/material.dart';

import '../../features/discovery/models/sport.dart';

/// Como se llama en castellano lo que dos personas acuerdan jugar.
///
/// Existe porque la app entrelaza tenis y correr, y "partido" solo vale
/// para uno de los dos: una quedada para correr no es un partido. Antes
/// cada pantalla escribia su propio literal ("Partido", "Cancelar
/// partido"), asi que a quien solo corre le hablaba de partidos todo el
/// rato. Centralizado aqui para que no vuelva a desincronizarse.
///
/// El termino paraguas es **quedada**: vale para los dos deportes, es como
/// se dice de verdad ("una quedada para correr", "quedada en el club") y,
/// a diferencia de "propuesta", sigue siendo correcto una vez aceptada.
String sportSessionTitle(Sport sport) =>
    sport == Sport.tennis ? 'Partido de tenis' : 'Salida a correr';

/// El sustantivo suelto, para meterlo dentro de una frase
/// ("Cancelar el $noun", "El $noun es el jueves").
String sportSessionNoun(Sport sport) =>
    sport == Sport.tennis ? 'partido' : 'salida';

IconData sportIcon(Sport sport) =>
    sport == Sport.tennis ? Icons.sports_tennis : Icons.directions_run;

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

/// Color de acento del deporte, para distinguir de un vistazo si una
/// tarjeta de Discovery es de tenis o de correr sin tener que leer nada.
///
/// No sale del `ColorScheme` a propósito: el verde de la app ya significa
/// "primario" en botones y estados, así que reutilizarlo para el deporte
/// mezclaría dos cosas distintas. Estos dos son de la misma familia que la
/// paleta (tierra batida y tartán de atletismo, igual que las fotos
/// generadas de `datagen`) pero inequívocamente diferentes entre sí.
Color sportAccent(Sport sport) => sport == Sport.tennis
    ? const Color(0xFFC65F3B) // tierra batida
    : const Color(0xFF3B7BC6); // azul pista de atletismo

/// Versión para texto sobre el acento.
Color sportOnAccent(Sport sport) => const Color(0xFFFFFFFF);

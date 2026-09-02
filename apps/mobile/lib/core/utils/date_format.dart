import '../i18n/app_locale.dart';

/// Fechas y horas escritas para leerse, en el idioma activo.
///
/// Los nombres de días y meses salen de `S.current`, no de constantes de este
/// fichero: eran castellano fijo y por eso la app entera se podía traducir
/// menos las fechas, que es de las cosas que más canta.
///
/// **Nada de `intl` con `DateFormat`.** Sólo hacen falta cinco formatos, todos
/// cortos, y el orden de las palabras ya lo resuelve `S.current.longDate` /
/// `dateAtTime`, que es justo lo que cambia entre idiomas ("12 **de** agosto"
/// contra "12 August"). Añadir el paquete y sus datos de locale para esto
/// sería más peso del que resuelve.

String _two(int n) => n.toString().padLeft(2, '0');

/// "lunes 12 de agosto a las 18:30" / "Monday 12 August at 18:30".
///
/// El formato largo es el correcto cuando hay que **presentarse** a esa hora,
/// que es de lo que va una propuesta.
String formatProposalDateTime(DateTime dt) {
  final d = dt.toLocal();
  final date = S.current.longDate(
    S.current.weekdayNames[d.weekday - 1],
    d.day,
    S.current.monthNames[d.month - 1],
  );
  return S.current.dateAtTime(date, formatTime(d));
}

/// Una fecha ya pasada, en corto: "12 ago" y, si fue de otro año, "12 ago 25".
///
/// En el historial la fecha sólo sirve para ordenar recuerdos: la hora exacta
/// a la que se jugó hace tres meses no le importa a nadie, y la frase larga se
/// comía la fila entera compitiendo con el nombre y el resultado.
String formatPastDate(DateTime dt) {
  final d = dt.toLocal();
  final month = S.current.monthNames[d.month - 1].substring(0, 3);
  final year = d.year == DateTime.now().year ? '' : " '${d.year % 100}";
  return '${d.day} $month$year';
}

/// Las tres piezas del bloque de fecha de una tarjeta de partido: "12",
/// "SEP", "vie".
///
/// Van sueltas y no en una frase porque se pintan una debajo de otra, como la
/// hoja de un calendario. Ése es el cambio que hace que la pantalla de
/// Partidos no se lea como una lista de conversaciones: en una tarjeta de
/// evento lo primero es *cuándo*, no quién.
({String day, String month, String weekday}) dateBlock(DateTime dt) {
  final d = dt.toLocal();
  return (
    day: '${d.day}',
    month: S.current.monthNames[d.month - 1].substring(0, 3).toUpperCase(),
    weekday: S.current.weekdayShort[d.weekday - 1],
  );
}

/// "Hoy", "Mañana", "En 3 días"… o null si queda lejos.
///
/// Null a partir de una semana a propósito: "en 34 días" no ayuda a nadie a
/// decidir nada, y la fecha de al lado ya lo dice mejor. Lo que sí cambia el
/// comportamiento es saber que es **hoy**.
String? relativeDay(DateTime dt) {
  final now = DateTime.now();
  final day = DateTime(dt.year, dt.month, dt.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = day.difference(today).inDays;

  if (diff < 0) return null;
  if (diff == 0) return S.current.today;
  if (diff == 1) return S.current.tomorrow;
  if (diff <= 7) return S.current.inDays(diff);
  return null;
}

/// "18:30".
String formatTime(DateTime dt) {
  final d = dt.toLocal();
  return '${_two(d.hour)}:${_two(d.minute)}';
}

/// "mié 2 sep · 19:00" — la fecha de una propuesta dentro del chat.
///
/// La restricción es el ancho: la burbuja es estrecha y siempre de tres
/// líneas, así que esto tiene que caber en una. El formato largo
/// ("miércoles 2 de septiembre a las 19:00") ocupaba dos, y por eso antes se
/// resolvía con la fecha en cifras, `02/09/2026 a las 19:00`.
///
/// Cabe igual sin hablar en números. Un partido se acuerda para dentro de
/// días, y lo primero que quiere saber quien lo lee es **qué día de la
/// semana** es —eso decide si puede— y no en qué mes del calendario cae. El
/// año sobra por lo mismo: no se propone un partido para el año que viene.
String formatShortDateTime(DateTime dt) {
  final d = dt.toLocal();
  final weekday = S.current.weekdayShort[d.weekday - 1];
  final month = S.current.monthNames[d.month - 1].substring(0, 3);
  return '$weekday ${d.day} $month · ${formatTime(d)}';
}

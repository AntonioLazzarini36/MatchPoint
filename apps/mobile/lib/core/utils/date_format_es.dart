const _weekdaysEs = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const _monthsEs = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "lunes 12 de agosto a las 18:30" - usado por las propuestas de partido
/// (tenis y correr), compartido para que el mensaje que se manda al chat
/// tenga el mismo formato sea cual sea el deporte.
String formatProposalDateTime(DateTime dt) {
  final weekday = _weekdaysEs[dt.weekday - 1];
  final month = _monthsEs[dt.month - 1];
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$weekday ${dt.day} de $month a las $hh:$mm';
}

/// Una fecha ya pasada, en corto: "12 ago" y, si fue de otro año, "12 ago 25".
///
/// El formato largo ("lunes 12 de agosto a las 18:30") es el correcto cuando
/// hay que **presentarse** a esa hora, que es de lo que va una propuesta. En
/// el historial no: ahí la fecha es sólo para ordenar los recuerdos, la hora
/// exacta a la que se jugó hace tres meses no le importa a nadie, y la frase
/// larga se comía la fila entera compitiendo con el nombre y el resultado.
String formatPastDate(DateTime dt) {
  final month = _monthsEs[dt.month - 1].substring(0, 3);
  final now = DateTime.now();
  final year = dt.year == now.year ? '' : " '${dt.year % 100}";
  return '${dt.day} $month$year';
}

/// Las tres piezas del bloque de fecha de una tarjeta de partido: "12",
/// "SEP", "vie".
///
/// Van sueltas y no en una frase porque se pintan una debajo de otra, como
/// la hoja de un calendario. Ése es justamente el cambio que hace que la
/// pantalla de Partidos no se lea como una lista de conversaciones: en una
/// tarjeta de evento lo primero es *cuándo*, no quién.
({String day, String month, String weekday}) dateBlockEs(DateTime dt) {
  final d = dt.toLocal();
  return (
    day: '${d.day}',
    month: _monthsEs[d.month - 1].substring(0, 3).toUpperCase(),
    weekday: _weekdaysEs[d.weekday - 1].substring(0, 3),
  );
}

/// "Hoy", "Mañana", "En 3 días"… o null si queda lejos.
///
/// Null a partir de una semana a propósito: "en 34 días" no ayuda a nadie a
/// decidir nada, y la fecha de al lado ya lo dice mejor. Lo que sí cambia el
/// comportamiento es saber que es **hoy**.
String? relativeDayEs(DateTime dt) {
  final now = DateTime.now();
  final day = DateTime(dt.year, dt.month, dt.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = day.difference(today).inDays;

  if (diff < 0) return null;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Mañana';
  if (diff <= 7) return 'En $diff días';
  return null;
}

/// "18:30".
String formatTimeEs(DateTime dt) {
  final d = dt.toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// "02/09/2026 a las 12:00".
///
/// El formato largo ("miércoles 2 de septiembre a las 12:00") se lee bien en
/// una ficha, donde hay sitio y se mira una vez. En una burbuja de chat, que
/// es estrecha y se recorre de un vistazo entre otros mensajes, ocupaba dos
/// líneas para decir lo mismo. El día de la semana es lo primero que sobra:
/// con la fecha delante, quien la lee ya sabe cuándo es.
String formatShortDateTime(DateTime dt) {
  final d = dt.toLocal();
  final dd = d.day.toString().padLeft(2, '0');
  final mo = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$dd/$mo/${d.year} a las $hh:$mm';
}

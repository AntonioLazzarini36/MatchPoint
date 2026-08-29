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

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

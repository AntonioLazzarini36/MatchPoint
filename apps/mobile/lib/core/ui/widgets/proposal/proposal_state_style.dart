import 'package:flutter/material.dart';

import '../../../../features/matches/models/proposal.dart';

/// Cómo se pinta el estado de una propuesta, **decidido en un solo sitio**.
///
/// La misma propuesta aparece en dos pantallas con formas distintas: en el
/// chat es una burbuja estrecha alineada a un lado (es un turno de la
/// conversación, y no lleva foto porque ya sabes con quién hablas), y en
/// Partidos es una fila a todo el ancho con foto (es una agenda entre varias
/// personas, y la foto es lo único que dice de quién es). Esa diferencia está
/// bien: responden a preguntas distintas.
///
/// Lo que no estaba bien es que el **mismo estado** se señalara distinto en
/// cada una — fondo lima en el chat, borde verde en Partidos — sin más motivo
/// que haberse escrito en momentos distintos. De ahí este fichero: la forma
/// puede diferir, el idioma no.
class ProposalStateStyle {
  final IconData icon;

  /// Fondo. La burbuja lo usa entero; la fila de Partidos, sólo cuando hay
  /// algo que hacer — ver [wantsAttention].
  final Color background;
  final Color foreground;
  final String headline;

  /// Si este estado **te pide algo a ti**.
  ///
  /// Es la distinción que faltaba: una propuesta pendiente de tu respuesta y
  /// otra en la que esperas tú a la otra persona son el mismo `PENDING` pero
  /// no piden lo mismo, y pintarlas igual gasta el color más llamativo de la
  /// app en algo que no requiere nada.
  final bool wantsAttention;

  /// Si el plan ya no va a ocurrir (rechazada o retirada).
  ///
  /// Cambia tres cosas: la fecha se tacha, la burbuja va **sin relleno** (ver
  /// [filled]) y deja de poder abrirse — los detalles de un partido que no va
  /// a jugarse no llevan a ninguna parte, y una pantalla sin nada que hacer es
  /// un callejón sin salida.
  final bool resolved;

  /// Relleno o sólo contorno.
  ///
  /// Es lo que separa "vivo" de "muerto" de un vistazo, y hacía falta porque
  /// dos estados distintos —una propuesta tuya esperando respuesta y una
  /// cancelada— acababan compartiendo el mismo gris de fondo. Con esto no
  /// pueden confundirse aunque el color se parezca: uno está pintado y el
  /// otro es un hueco con borde.
  bool get filled => !resolved;

  const ProposalStateStyle({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.headline,
    required this.wantsAttention,
    required this.resolved,
  });
}

ProposalStateStyle proposalStateStyle(
  BuildContext context,
  Proposal proposal, {
  /// En Partidos el titular acompaña a un nombre y una fecha, así que puede
  /// ser más escueto; en el chat es lo único que dice qué ha pasado.
  bool short = false,
}) {
  final c = Theme.of(context).colorScheme;

  switch (proposal.status) {
    case ProposalStatus.pending:
      // Sólo lo que espera **tu** respuesta se lleva el color fuerte.
      return proposal.mine
          ? ProposalStateStyle(
              icon: Icons.hourglass_empty,
              // Pizarra, no el gris de superficie: ese lo llevaban también
              // las canceladas, así que "esperando respuesta" y "cancelada"
              // salían del mismo color pese a ser cosas opuestas — una sigue
              // en pie y la otra no.
              background: c.secondaryContainer,
              foreground: c.onSecondaryContainer,
              headline: short ? 'Esperando respuesta' : 'Has propuesto un partido',
              wantsAttention: false,
              resolved: false,
            )
          : ProposalStateStyle(
              icon: Icons.schedule,
              background: c.tertiaryContainer,
              foreground: c.onTertiaryContainer,
              headline: short ? 'Espera tu respuesta' : 'Te propone un partido',
              wantsAttention: true,
              resolved: false,
            );

    case ProposalStatus.accepted:
      return ProposalStateStyle(
        icon: Icons.event_available,
        background: c.primaryContainer,
        foreground: c.onPrimaryContainer,
        headline: 'Partido confirmado',
        wantsAttention: false,
        resolved: false,
      );

    case ProposalStatus.declined:
      return ProposalStateStyle(
        icon: Icons.event_busy,
        background: c.surfaceContainerHighest,
        foreground: c.onSurfaceVariant,
        headline: proposal.mine ? 'No les venía bien' : 'Propuesta rechazada',
        wantsAttention: false,
        resolved: true,
      );

    case ProposalStatus.cancelled:
      return ProposalStateStyle(
        icon: Icons.event_busy,
        background: c.surfaceContainerHighest,
        foreground: c.onSurfaceVariant,
        headline: proposal.mine
            ? 'Propuesta cancelada'
            : 'Retiraron la propuesta',
        wantsAttention: false,
        resolved: true,
      );
  }
}

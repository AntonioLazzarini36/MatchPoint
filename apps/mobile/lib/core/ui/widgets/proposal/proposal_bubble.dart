import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/date_format_es.dart';
import '../../../../features/matches/models/proposal.dart';
import 'proposal_state_style.dart';

/// Una propuesta dentro de la conversación, con forma de mensaje.
///
/// Antes vivía fijada arriba del chat, en un bloque de media pantalla. Se
/// puso ahí para que no se perdiera scrolleando — el problema real de cuando
/// proponer era mandar un texto suelto — pero se pasó de frenada: ocupaba
/// tantísimo que tapaba la conversación, y una propuesta resuelta se quedaba
/// clavada sin nada que hacer con ella.
///
/// Aquí va en la línea de tiempo, donde ocurrió, y se comporta como lo que es:
/// un mensaje. Se apila con los demás, se queda cuando se cancela, y sube con
/// el scroll. Lo que no hace es intentar caber entero — sólo el titular, la
/// fecha y el sitio; **al tocarla se abre la ficha** con todo y con los
/// botones (ver `showProposalSheet`).
class ProposalBubble extends StatelessWidget {
  final Proposal proposal;
  final VoidCallback onTap;

  const ProposalBubble({
    super.key,
    required this.proposal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    // El estado sale de `proposalStateStyle`, compartido con la fila de
    // Partidos: la forma de las dos puede diferir, el idioma no.
    final style = proposalStateStyle(context, proposal);

    return Align(
      // Al lado que le toca, como cualquier mensaje: lo que has mandado tú a
      // la derecha, lo que te mandan a la izquierda.
      alignment: proposal.mine ? Alignment.centerRight : Alignment.centerLeft,
      // **Ancho fijo, no ajustado al contenido.** Estas no son burbujas de
      // texto: son fichas, y una ficha que cambia de tamaño según lo largo
      // que sea su titular ("Partido confirmado" contra "Retiraron la
      // propuesta") se lee como si fueran cosas distintas. Con el mismo ancho
      // y las mismas tres líneas siempre, lo único que las distingue es el
      // color, que es justo lo que tiene que distinguirlas.
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.72,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: style.filled ? style.background : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            // Sin relleno cuando ya no va a pasar: contorno y nada más.
            shape: style.filled
                ? null
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: BorderSide(color: context.colors.outlineVariant),
                  ),
            child: InkWell(
              // Una propuesta resuelta no se abre: dentro no hay nada que
              // hacer con ella.
              onTap: style.resolved ? null : onTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, size: 16, color: style.foreground),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            style.headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelLarge?.copyWith(
                              color: style.foreground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatShortDateTime(proposal.scheduledAt),
                      style: t.bodyMedium?.copyWith(
                        color: style.foreground,
                        // Tachada cuando ya no va a pasar: se entiende sin
                        // leer el titular.
                        decoration: style.resolved
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    // Siempre esta línea, aunque no haya sitio: si aparece
                    // sólo a veces, unas fichas miden tres líneas y otras dos
                    // y la columna se ve descuadrada. Y "sin sitio" es
                    // información de verdad — se puede proponer sin él.
                    Text(
                      proposal.placeName ?? 'Sin sitio concreto',
                      style: t.bodySmall?.copyWith(
                        color: style.foreground,
                        fontStyle: proposal.placeName == null
                            ? FontStyle.italic
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

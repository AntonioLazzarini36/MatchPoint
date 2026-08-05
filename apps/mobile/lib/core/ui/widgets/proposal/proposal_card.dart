import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/date_format_es.dart';
import '../../../../features/discovery/models/sport.dart';
import '../../../../features/matches/models/proposal.dart';

/// La propuesta viva de un chat, fijada arriba del todo.
///
/// Deliberadamente NO es una burbuja mas dentro del listado de mensajes:
/// el problema que resuelve es justo que antes se perdia scrolleando. Se
/// muestra la ultima propuesta relevante y, si esta pendiente, los botones
/// que la resuelven.
class ProposalCard extends StatelessWidget {
  final Proposal proposal;
  final bool busy;

  /// Solo tienen sentido si `proposal.isPending`. Aceptar/rechazar es de
  /// quien la recibio; cancelar, de quien la hizo — el widget elige cual
  /// enseñar con `proposal.mine`, y el backend lo vuelve a comprobar.
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  const ProposalCard({
    super.key,
    required this.proposal,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final styles = context.textStyles;
    final (icon, tint, headline) = _presentation(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tint, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: styles.titleSmall?.copyWith(
                    color: tint,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                proposal.sport == Sport.tennis
                    ? Icons.sports_tennis
                    : Icons.directions_run,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatProposalDateTime(proposal.scheduledAt),
                  style: styles.bodyLarge,
                ),
              ),
            ],
          ),
          if (proposal.placeName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    proposal.placeName!,
                    style: styles.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (proposal.isPending) ...[
            const SizedBox(height: 14),
            _actions(context),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    if (busy) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Quien propone no puede aceptarse a si mismo — solo retirarla.
    if (proposal.mine) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Cancelar propuesta'),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onDecline,
            child: const Text('Rechazar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onAccept,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Aceptar'),
          ),
        ),
      ],
    );
  }

  /// Icono, color y titular segun estado — y, si esta pendiente, segun
  /// quien tiene la pelota.
  (IconData, Color, String) _presentation(BuildContext context) {
    final colors = context.colors;
    switch (proposal.status) {
      case ProposalStatus.pending:
        return (
          Icons.schedule,
          colors.primary,
          proposal.mine ? 'Propuesta enviada' : 'Te han propuesto jugar',
        );
      case ProposalStatus.accepted:
        // El verde de la paleta, no el `Colors.green` de Material: con
        // el tema de pista, el verde generico se ve fuera de sitio.
        return (Icons.event_available, colors.primary, '¡Confirmado!');
      case ProposalStatus.declined:
        return (
          Icons.event_busy,
          colors.error,
          proposal.mine ? 'No les venía bien' : 'Propuesta rechazada',
        );
      case ProposalStatus.cancelled:
        return (
          Icons.event_busy,
          colors.outline,
          proposal.mine ? 'Propuesta cancelada' : 'Retiraron la propuesta',
        );
    }
  }
}

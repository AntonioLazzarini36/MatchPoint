import 'package:flutter/material.dart';

import '../../network/connection_error.dart';
import '../../theme/app_theme.dart';
import 'package:match_point/core/i18n/app_locale.dart';

/// Cómo enseña la app que algo ha fallado al cargar.
///
/// Antes cada pantalla lo resolvía a su manera —o no lo resolvía— y lo que
/// se veía era el `toString()` de la excepción cruda. Un fallo de red es la
/// cosa más normal del mundo en un móvil (el metro, el ascensor, la propia
/// pista), así que merece verse como algo esperado y no como que la app se
/// ha roto.
///
/// La diferencia entre los dos casos importa: sin conexión, reintentar es
/// exactamente lo que hay que ofrecer; ante un error del servidor, el botón
/// sigue estando pero el texto no promete que vaya a funcionar.
class ErrorStateView extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const ErrorStateView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final offline = isConnectionError(error);

    return ListView(
      // ListView y no Center pelado para que el pull-to-refresh siga
      // funcionando encima del error.
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 120),
        Icon(
          offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          size: 56,
          color: context.colors.outline,
        ),
        const SizedBox(height: 16),
        Text(
          offline ? S.current.noConnection : S.current.somethingWentWrong,
          textAlign: TextAlign.center,
          style: context.textStyles.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          friendlyError(error),
          textAlign: TextAlign.center,
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(S.current.retry),
          ),
        ),
      ],
    );
  }
}

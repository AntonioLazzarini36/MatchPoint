import 'dart:async';

import 'package:flutter/material.dart';

import '../../location/geocoding_service.dart';
import '../../location/location_result.dart';
import '../../theme/app_theme.dart';
import '../../../core/network/connection_error.dart';

/// Buscador de sitio a pantalla completa — se abre con `Navigator.push` y
/// devuelve el [LocationResult] elegido (o null si se sale sin elegir).
///
/// **Entiende códigos postales.** Si lo que se escribe son cinco dígitos, se
/// busca por código postal en vez de por nombre; cualquier otra cosa va al
/// buscador de siempre. Así Ajustes funciona igual que el registro, donde el
/// código postal es la vía principal, sin tener dos pantallas distintas para
/// lo mismo — y sin obligar a nadie a saber por cuál de las dos ha entrado.
class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _geocoding = GeocodingService();
  final _controller = TextEditingController();
  Timer? _debounce;

  List<LocationResult> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }

    // Nominatim's usage policy asks for max ~1 request/second — debounce
    // so we only search once the user pauses typing.
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  /// Cinco dígitos seguidos y nada más: un código postal español.
  static bool _looksLikePostalCode(String query) =>
      RegExp(r'^\d{5}$').hasMatch(query.trim());

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = _looksLikePostalCode(query)
          ? await _geocoding.searchPostalCode(query)
          : await _geocoding.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e, fallback: 'No se han podido buscar sitios.');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Código postal o ciudad',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.error,
            ),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _controller.text.trim().isEmpty
                ? 'Escribe tu código postal (29630) o el nombre de tu '
                      'ciudad.'
                // Nominatim es un geocodificador: encuentra sitios con
                // nombre y direcciones, pero no sirve para "búscame un
                // club de tenis" — para eso está el selector de clubes
                // del flujo de propuestas, que consulta OpenStreetMap por
                // etiqueta.
                : _looksLikePostalCode(_controller.text)
                ? 'No encontramos ese código postal. Revísalo o busca tu '
                      'ciudad por el nombre.'
                : 'Sin resultados. Prueba con el nombre exacto del sitio o '
                      'con el municipio.',
            textAlign: TextAlign.center,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final result = _results[i];
        return ListTile(
          leading: Icon(
            Icons.location_on_outlined,
            color: context.colors.primary,
          ),
          title: Text(result.displayName),
          onTap: () => Navigator.of(context).pop(result),
        );
      },
    );
  }
}

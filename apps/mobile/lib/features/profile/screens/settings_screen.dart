import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/location/location_result.dart';
import '../../../core/network/api.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/location/location_search_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../discovery/models/sport.dart';
import '../../onboarding/models/profile.dart';
import '../../onboarding/services/profile_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ProfileService _profileService;
  late final AuthService _authService;

  bool _loading = true;
  String? _email;
  Profile? _profile;
  Preferences? _preferences;
  bool _loggingOut = false;
  bool _savingLocation = false;
  bool _savingRadius = false;
  bool _savingSports = false;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService(Api.client);
    _authService = AuthService(Api.client);
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await _profileService.getMe();
      if (!mounted) return;
      setState(() {
        _email = me.email;
        _profile = me.profile;
        _preferences = me.preferences;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Cambiar la ubicación es posible en cualquier momento, no solo en el
  /// onboarding — mismo buscador (Nominatim), nunca GPS del dispositivo.
  Future<void> _changeLocation() async {
    final result = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
    if (result == null || !mounted) return;

    setState(() => _savingLocation = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateLocation(result);
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la ubicación: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingLocation = false);
    }
  }

  /// El radio solo se podía setear una vez, en el onboarding — mismo
  /// endpoint (`PATCH /me/preferences`) que ya existía, ahora también
  /// editable desde acá en cualquier momento.
  Future<void> _changeRadius() async {
    final current = _preferences?.distanceKm ?? 25;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => _RadiusSheet(initialKm: current),
    );
    if (chosen == null || !mounted) return;

    setState(() => _savingRadius = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateDiscoveryRadius(chosen);
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el radio: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingRadius = false);
    }
  }

  /// Antes solo se podía elegir en el onboarding — este es el bug de
  /// status.md: `DiscoveryController` ignoraba `Profile.sports` del todo
  /// (fijo en tenis), y encima no había forma de cambiarlo después. Ahora
  /// Discovery sí lo respeta (ver discovery_controller.dart), y esta fila
  /// deja editarlo en cualquier momento, mismo patrón que Ubicación/Radio.
  Future<void> _changeSports() async {
    final current = _profile?.sports ?? const [Sport.tennis, Sport.running];
    final chosen = await showModalBottomSheet<List<Sport>>(
      context: context,
      builder: (sheetContext) => _SportsSheet(initialSports: current),
    );
    if (chosen == null || !mounted) return;

    setState(() => _savingSports = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateSports(chosen);
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudieron actualizar los deportes: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingSports = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _logout();
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);

    await _authService.logout();
    await TokenStorage.clear();

    if (!mounted) return;
    context.go(AppRoutes.welcome);
  }

  String get _sportsSubtitle {
    final sports = _profile?.sports ?? const [];
    if (sports.isEmpty) return 'Sin definir';
    return sports.map((s) => s.label).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.paddingLg,
              children: [
                _ProfileHeaderCard(
                  displayName: _profile?.displayName ?? 'Sin nombre',
                  photoUrl: _profile?.mainPhoto,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_email != null) ...[
                  _SettingsGroup(
                    children: [
                      _SettingsRow(
                        icon: Icons.email_outlined,
                        iconBackground: context.colors.secondaryContainer,
                        iconColor: context.colors.onSecondaryContainer,
                        title: 'Email',
                        subtitle: _email!,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xs,
                    bottom: AppSpacing.sm,
                  ),
                  child: Text('Perfil', style: context.textStyles.titleMedium),
                ),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.location_on_outlined,
                      iconBackground: context.colors.tertiaryContainer,
                      iconColor: context.colors.onTertiaryContainer,
                      title: 'Ubicación',
                      subtitle: _profile?.city ?? 'Sin definir',
                      trailing: _savingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: context.colors.outline,
                            ),
                      onTap: _savingLocation ? null : _changeLocation,
                    ),
                    _SettingsRow(
                      icon: Icons.social_distance_outlined,
                      iconBackground: context.colors.tertiaryContainer,
                      iconColor: context.colors.onTertiaryContainer,
                      title: 'Radio de búsqueda',
                      subtitle: '${_preferences?.distanceKm ?? 25} km',
                      trailing: _savingRadius
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: context.colors.outline,
                            ),
                      onTap: _savingRadius ? null : _changeRadius,
                    ),
                    _SettingsRow(
                      icon: Icons.sports_tennis,
                      iconBackground: context.colors.tertiaryContainer,
                      iconColor: context.colors.onTertiaryContainer,
                      title: 'Deportes',
                      subtitle: _sportsSubtitle,
                      trailing: _savingSports
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: context.colors.outline,
                            ),
                      onTap: _savingSports ? null : _changeSports,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xs,
                    bottom: AppSpacing.sm,
                  ),
                  child: Text('Cuenta', style: context.textStyles.titleMedium),
                ),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.logout,
                      iconBackground: context.colors.error.withValues(
                        alpha: 0.12,
                      ),
                      iconColor: context.colors.error,
                      title: 'Cerrar sesión',
                      titleColor: context.colors.error,
                      trailing: _loggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: context.colors.outline,
                            ),
                      onTap: _loggingOut ? null : _confirmLogout,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Card de cabecera con foto + nombre del usuario, mismo lenguaje visual
/// que el resto del perfil (fondo `primary`, texto blanco).
class _ProfileHeaderCard extends StatelessWidget {
  final String displayName;
  final String? photoUrl;

  const _ProfileHeaderCard({required this.displayName, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: context.colors.onPrimary.withValues(alpha: 0.2),
            backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
            child: photoUrl == null
                ? Icon(Icons.person, color: context.colors.onPrimary, size: 32)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              displayName,
              style: context.textStyles.headlineSmall?.withColor(
                context.colors.onPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta que agrupa varias `_SettingsRow`, con un divisor fino entre cada
/// una — mismo patrón de "card contenedora + filas" que las mockups.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.surfaceContainerHighest),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: AppSpacing.md + 40 + AppSpacing.md,
                color: context.colors.surfaceContainerHighest,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBackground,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: context.textStyles.titleSmall?.withColor(
          titleColor ?? context.colors.onSurface,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: context.textStyles.bodySmall?.withColor(
                context.colors.outline,
              ),
            ),
      trailing: trailing,
    );
  }
}

class _RadiusSheet extends StatefulWidget {
  final int initialKm;

  const _RadiusSheet({required this.initialKm});

  @override
  State<_RadiusSheet> createState() => _RadiusSheetState();
}

class _RadiusSheetState extends State<_RadiusSheet> {
  late double _km;

  @override
  void initState() {
    super.initState();
    _km = widget.initialKm.toDouble().clamp(1, 100);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Radio de búsqueda', style: context.textStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Hasta dónde mostramos gente en Discovery, desde tu ubicación.',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text('${_km.round()} km', style: context.textStyles.titleLarge),
            Slider(
              value: _km,
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: (v) => setState(() => _km = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_km.round()),
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SportsSheet extends StatefulWidget {
  final List<Sport> initialSports;

  const _SportsSheet({required this.initialSports});

  @override
  State<_SportsSheet> createState() => _SportsSheetState();
}

class _SportsSheetState extends State<_SportsSheet> {
  late Set<Sport> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSports.toSet();
  }

  void _toggle(Sport sport, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(sport);
      } else {
        _selected.remove(sport);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Al menos un deporte tiene que quedar marcado — con cero, Discovery no
    // tendría por qué mostrar a nadie (ver discovery_controller.dart).
    final canSave = _selected.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deportes', style: context.textStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Qué deportes jugás — determina a quién ves en Discovery y '
              'quién te ve a vos.',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilterChip(
                  label: const Text('Tenis'),
                  avatar: const Icon(Icons.sports_tennis, size: 18),
                  selected: _selected.contains(Sport.tennis),
                  onSelected: (v) => _toggle(Sport.tennis, v),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                ),
                FilterChip(
                  label: const Text('Correr'),
                  avatar: const Icon(Icons.directions_run, size: 18),
                  selected: _selected.contains(Sport.running),
                  onSelected: (v) => _toggle(Sport.running, v),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSave
                    ? () => Navigator.of(context).pop(_selected.toList())
                    : null,
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

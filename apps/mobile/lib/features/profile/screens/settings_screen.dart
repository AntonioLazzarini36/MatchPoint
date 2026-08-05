import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/location/location_result.dart';
import '../../../core/network/api.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/dialogs/confirm_changes_dialog.dart';
import '../../../core/ui/location/location_search_screen.dart';
import '../../../core/utils/pace_format.dart';
import '../../auth/screens/email_verification_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../discovery/models/skill_level.dart';
import '../../discovery/models/sport.dart';
import '../../onboarding/models/gender.dart';
import '../../onboarding/models/profile.dart';
import '../../../core/ui/widgets/discovery/discovery_preferences_sheet.dart';
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
  bool _emailVerified = false;
  Profile? _profile;
  Preferences? _preferences;
  Map<Sport, SkillLevel> _skillLevels = {};
  bool _loggingOut = false;
  bool _savingLocation = false;
  bool _savingRadius = false;
  bool _savingSports = false;
  bool _savingSkillLevels = false;
  bool _savingCredentials = false;
  bool _savingPreferences = false;

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
        _emailVerified = me.emailVerified;
        _profile = me.profile;
        _preferences = me.preferences;
        _skillLevels = me.skillLevels;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Abre la pantalla del código. Al volver se recarga `/me` en vez de
  /// fiarse del resultado: el estado real lo tiene el backend, y así la
  /// fila no puede quedarse diciendo "sin verificar" tras verificarlo.
  Future<void> _verifyEmail() async {
    final email = _email;
    if (email == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(email: email),
      ),
    );
    if (mounted) await _load();
  }

  /// Cambiar la ubicación es posible en cualquier momento, no solo en el
  /// onboarding — mismo buscador (Nominatim), nunca GPS del dispositivo.
  Future<void> _changeLocation() async {
    final result = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
    if (result == null || !mounted) return;

    final ok = await confirmChanges(
      context,
      title: 'Cambiar ubicación',
      changes: [
        FieldChange(
          label: 'Ubicación',
          before: _profile?.city ?? '',
          after: result.displayName,
        ),
      ],
    );
    if (!ok || !mounted) return;

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

    final ok = await confirmChanges(
      context,
      title: 'Cambiar radio de búsqueda',
      changes: [
        FieldChange(
          label: 'Radio',
          before: '$current km',
          after: '$chosen km',
        ),
      ],
    );
    if (!ok || !mounted) return;

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

    final ok = await confirmChanges(
      context,
      title: 'Cambiar tus deportes',
      changes: [
        FieldChange(
          label: 'Deportes que juegas',
          before: current.map((s) => s.label).join(', '),
          after: chosen.map((s) => s.label).join(', '),
        ),
      ],
    );
    if (!ok || !mounted) return;

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

  /// Nivel auto-declarado por deporte — ver status.md,
  /// "Reposicionamiento de producto". Solo se puede setear nivel para los
  /// deportes que el usuario ya juega (`_profile.sports`).
  Future<void> _changeSkillLevels() async {
    final sports = _profile?.sports ?? const [];
    if (sports.isEmpty) return;

    final chosen = await showModalBottomSheet<Map<Sport, SkillLevel>>(
      context: context,
      builder: (sheetContext) =>
          _SkillLevelSheet(sports: sports, initialLevels: _skillLevels),
    );
    if (chosen == null || !mounted) return;

    final ok = await confirmChanges(
      context,
      title: 'Cambiar tu nivel',
      changes: [
        for (final sport in sports)
          FieldChange(
            label: sport.label,
            before: _skillLevels[sport]?.label ?? '',
            after: chosen[sport]?.label ?? '',
          ),
      ],
    );
    if (!ok || !mounted) return;

    setState(() => _savingSkillLevels = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateSkillLevels(chosen);
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el nivel: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingSkillLevels = false);
    }
  }

  /// Señales de confianza estructuradas (años jugando, club, logros) — ver
  /// status.md, "Reposicionamiento de producto".
  Future<void> _changeCredentials() async {
    final chosen = await showModalBottomSheet<_CredentialsResult>(
      context: context,
      builder: (sheetContext) => _CredentialsSheet(
        sports: _profile?.sports ?? const [],
        initialYearsPlaying: _profile?.yearsPlaying,
        initialClub: _profile?.club ?? '',
        initialAvgPaceMinPerKm: _profile?.avgPaceMinPerKm,
        initialAvgDistanceKm: _profile?.avgDistanceKm,
        initialAchievements: _profile?.achievements ?? const [],
      ),
    );
    if (chosen == null || !mounted) return;

    String pace(double? value) =>
        value == null ? '' : '${formatPaceMinPerKm(value)} min/km';
    String km(double? value) => value == null ? '' : '$value km';
    String years(int? value) => value == null ? '' : '$value años';

    final ok = await confirmChanges(
      context,
      title: 'Cambiar tus credenciales',
      changes: [
        FieldChange(
          label: 'Años jugando',
          before: years(_profile?.yearsPlaying),
          after: years(chosen.yearsPlaying),
        ),
        FieldChange(
          label: 'Club',
          before: _profile?.club ?? '',
          after: chosen.club ?? '',
        ),
        FieldChange(
          label: 'Ritmo medio',
          before: pace(_profile?.avgPaceMinPerKm),
          after: pace(chosen.avgPaceMinPerKm),
        ),
        FieldChange(
          label: 'Distancia media',
          before: km(_profile?.avgDistanceKm),
          after: km(chosen.avgDistanceKm),
        ),
        FieldChange(
          label: 'Logros',
          before: (_profile?.achievements ?? const []).join(', '),
          after: chosen.achievements.join(', '),
        ),
      ],
    );
    if (!ok || !mounted) return;

    setState(() => _savingCredentials = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateCredentials(
        yearsPlaying: chosen.yearsPlaying,
        club: chosen.club,
        avgPaceMinPerKm: chosen.avgPaceMinPerKm,
        avgDistanceKm: chosen.avgDistanceKm,
        achievements: chosen.achievements,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudieron actualizar las credenciales: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingCredentials = false);
    }
  }

  /// A quién mostrar en Discovery (edad, deportes que quiere ver, género)
  /// — independiente del radio (fila de arriba) y de los deportes que
  /// juega. Misma hoja que abre el botón de filtros dentro de Discovery,
  /// y se guarda sola, así que aquí solo hay que recargar.
  Future<void> _changePreferences() async {
    final saved = await showDiscoveryPreferencesSheet(
      context,
      current: _preferences,
      mySports: _profile?.sports ?? const [],
    );
    if (!saved || !mounted) return;

    setState(() => _savingPreferences = true);
    try {
      await _load();
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
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

  String get _skillLevelsSubtitle {
    final sports = _profile?.sports ?? const [];
    if (sports.isEmpty) return 'Elige tus deportes primero';
    final parts = sports
        .map((s) => _skillLevels[s] == null ? null : '${s.label}: ${_skillLevels[s]!.label}')
        .whereType<String>()
        .toList();
    return parts.isEmpty ? 'Sin definir' : parts.join(' · ');
  }

  String get _credentialsSubtitle {
    final parts = <String>[
      if (_profile?.yearsPlaying != null)
        '${_profile!.yearsPlaying} años jugando',
      if ((_profile?.club ?? '').isNotEmpty) _profile!.club!,
      if (_profile?.avgPaceMinPerKm != null)
        '${formatPaceMinPerKm(_profile!.avgPaceMinPerKm)} min/km',
      if (_profile?.avgDistanceKm != null)
        '${_profile!.avgDistanceKm} km medios',
      if ((_profile?.achievements ?? const []).isNotEmpty)
        '${_profile!.achievements.length} logro(s)',
    ];
    return parts.isEmpty ? 'Sin definir' : parts.join(' · ');
  }

  String get _preferencesSubtitle {
    final prefs = _preferences;
    if (prefs == null) return 'Sin definir';
    final parts = <String>[
      '${prefs.ageMin}-${prefs.ageMax} años',
      if (prefs.sportsWanted.isNotEmpty)
        prefs.sportsWanted.map((s) => s.label).join(', '),
      prefs.genderPreference?.pluralLabel ?? 'Cualquiera',
    ];
    return parts.join(' · ');
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
                      // Verificado o no, la fila es la misma: cambia el
                      // icono, el subtítulo y si se puede tocar. Así el
                      // estado del email se ve siempre, no sólo cuando
                      // hay algo que hacer.
                      _SettingsRow(
                        icon: _emailVerified
                            ? Icons.mark_email_read_outlined
                            : Icons.mark_email_unread_outlined,
                        iconBackground: _emailVerified
                            ? context.colors.secondaryContainer
                            : context.colors.tertiaryContainer,
                        iconColor: _emailVerified
                            ? context.colors.onSecondaryContainer
                            : context.colors.onTertiaryContainer,
                        title: 'Email',
                        subtitle: _emailVerified
                            ? '${_email!}\nVerificado'
                            : '${_email!}\nSin verificar — toca para confirmarlo',
                        onTap: _emailVerified ? null : _verifyEmail,
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
                    _SettingsRow(
                      icon: Icons.military_tech_outlined,
                      iconBackground: context.colors.tertiaryContainer,
                      iconColor: context.colors.onTertiaryContainer,
                      title: 'Nivel',
                      subtitle: _skillLevelsSubtitle,
                      trailing: _savingSkillLevels
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
                      onTap: _savingSkillLevels ? null : _changeSkillLevels,
                    ),
                    _SettingsRow(
                      icon: Icons.emoji_events_outlined,
                      iconBackground: context.colors.tertiaryContainer,
                      iconColor: context.colors.onTertiaryContainer,
                      title: 'Credenciales',
                      subtitle: _credentialsSubtitle,
                      trailing: _savingCredentials
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
                      onTap: _savingCredentials ? null : _changeCredentials,
                    ),
                    _SettingsRow(
                      icon: Icons.tune,
                      iconBackground: context.colors.tertiaryContainer,
                      iconColor: context.colors.onTertiaryContainer,
                      title: 'Preferencias de Discovery',
                      subtitle: _preferencesSubtitle,
                      trailing: _savingPreferences
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
                      onTap: _savingPreferences ? null : _changePreferences,
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
      // Con subtitulo de dos lineas, ListTile necesita saberlo para
      // repartir bien el alto; sin esto el texto queda pegado al borde.
      isThreeLine: subtitle?.contains('\n') ?? false,
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

class _SkillLevelSheet extends StatefulWidget {
  final List<Sport> sports;
  final Map<Sport, SkillLevel> initialLevels;

  const _SkillLevelSheet({required this.sports, required this.initialLevels});

  @override
  State<_SkillLevelSheet> createState() => _SkillLevelSheetState();
}

class _SkillLevelSheetState extends State<_SkillLevelSheet> {
  late Map<Sport, SkillLevel> _levels;

  @override
  void initState() {
    super.initState();
    _levels = Map<Sport, SkillLevel>.from(widget.initialLevels);
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
            Text('Nivel', style: context.textStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Para que quien vea tu perfil sepa si juega a tu nivel.',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final sport in widget.sports) ...[
              Text(sport.label, style: context.textStyles.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SkillLevel.values.map((level) {
                  return ChoiceChip(
                    label: Text(level.label),
                    selected: _levels[sport] == level,
                    onSelected: (_) => setState(() => _levels[sport] = level),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_levels),
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CredentialsResult {
  final int? yearsPlaying;
  final String? club;
  final double? avgPaceMinPerKm;
  final double? avgDistanceKm;
  final List<String> achievements;

  const _CredentialsResult({
    required this.yearsPlaying,
    required this.club,
    required this.avgPaceMinPerKm,
    required this.avgDistanceKm,
    required this.achievements,
  });
}

class _CredentialsSheet extends StatefulWidget {
  final List<Sport> sports;
  final int? initialYearsPlaying;
  final String initialClub;
  final double? initialAvgPaceMinPerKm;
  final double? initialAvgDistanceKm;
  final List<String> initialAchievements;

  const _CredentialsSheet({
    required this.sports,
    required this.initialYearsPlaying,
    required this.initialClub,
    required this.initialAvgPaceMinPerKm,
    required this.initialAvgDistanceKm,
    required this.initialAchievements,
  });

  @override
  State<_CredentialsSheet> createState() => _CredentialsSheetState();
}

class _CredentialsSheetState extends State<_CredentialsSheet> {
  late final TextEditingController _yearsCtrl;
  late final TextEditingController _clubCtrl;
  late final TextEditingController _paceCtrl;
  late final TextEditingController _distanceCtrl;
  late final TextEditingController _achievementCtrl;
  late List<String> _achievements;
  String? _error;

  @override
  void initState() {
    super.initState();
    _yearsCtrl = TextEditingController(
      text: widget.initialYearsPlaying?.toString() ?? '',
    );
    _clubCtrl = TextEditingController(text: widget.initialClub);
    _paceCtrl = TextEditingController(
      text: formatPaceMinPerKm(widget.initialAvgPaceMinPerKm),
    );
    _distanceCtrl = TextEditingController(
      text: widget.initialAvgDistanceKm?.toString() ?? '',
    );
    _achievementCtrl = TextEditingController();
    _achievements = [...widget.initialAchievements];
  }

  @override
  void dispose() {
    _yearsCtrl.dispose();
    _clubCtrl.dispose();
    _paceCtrl.dispose();
    _distanceCtrl.dispose();
    _achievementCtrl.dispose();
    super.dispose();
  }

  static const _maxAchievements = 10;
  static const _maxAchievementLength = 80;
  static const _maxClubLength = 60;

  void _addAchievement() {
    final text = _achievementCtrl.text.trim();
    if (text.isEmpty) return;
    if (text.length > _maxAchievementLength) {
      setState(() => _error = 'Máximo $_maxAchievementLength caracteres por logro');
      return;
    }
    if (_achievements.length >= _maxAchievements) {
      setState(() => _error = 'Máximo $_maxAchievements logros');
      return;
    }
    setState(() {
      _error = null;
      _achievements.add(text);
      _achievementCtrl.clear();
    });
  }

  void _removeAchievement(int index) {
    setState(() => _achievements.removeAt(index));
  }

  void _save() {
    final club = _clubCtrl.text.trim();
    if (club.length > _maxClubLength) {
      setState(() => _error = 'El club no puede superar los $_maxClubLength caracteres');
      return;
    }
    Navigator.of(context).pop(
      _CredentialsResult(
        yearsPlaying: int.tryParse(_yearsCtrl.text.trim()),
        club: club,
        avgPaceMinPerKm: parsePaceMinPerKm(_paceCtrl.text),
        avgDistanceKm: double.tryParse(_distanceCtrl.text.trim()),
        achievements: _achievements,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playsTennis = widget.sports.contains(Sport.tennis);
    final playsRunning = widget.sports.contains(Sport.running);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Credenciales', style: context.textStyles.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Lo que quieras que se vea en tu perfil para dar confianza.',
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (playsTennis) ...[
                TextField(
                  controller: _yearsCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Años jugando al tenis',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _clubCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(labelText: 'Club'),
                ),
                const SizedBox(height: 12),
              ],
              if (playsRunning) ...[
                TextField(
                  controller: _paceCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Ritmo medio (min:seg / km)',
                    hintText: 'Ej. 4:30',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9:.]')),
                    LengthLimitingTextInputFormatter(5),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _distanceCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Distancia media (km)',
                    hintText: 'Ej. 10',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              Text('Torneos / logros', style: context.textStyles.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _achievementCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Campeón provincial 2024',
                      ),
                      onSubmitted: (_) => _addAchievement(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addAchievement,
                  ),
                ],
              ),
              if (_achievements.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _achievements.length; i++)
                      Chip(
                        label: Text(_achievements[i]),
                        onDeleted: () => _removeAchievement(i),
                      ),
                  ],
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: context.textStyles.bodySmall?.withColor(
                      context.colors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

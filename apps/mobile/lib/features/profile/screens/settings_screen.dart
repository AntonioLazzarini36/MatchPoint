import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/location/location_result.dart';
import '../../../core/network/api.dart';
import '../../../core/push/push_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/dialogs/delete_account_dialog.dart';
import '../../../core/ui/location/location_search_screen.dart';
import '../../../core/utils/pace_format.dart';
import '../../../core/utils/sport_words.dart';
import '../../auth/screens/email_verification_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../discovery/models/skill_level.dart';
import '../../discovery/models/sport.dart';
import '../../../core/network/connection_error.dart';
import '../../../core/ui/widgets/availability_picker.dart';
import '../../onboarding/models/availability.dart';
import '../../../core/utils/app_sports.dart';
import '../../onboarding/models/intention.dart';
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
  bool _emailVerified = false;
  bool _emailVerificationEnabled = true;
  Profile? _profile;
  Preferences? _preferences;
  Map<Sport, SkillLevel> _skillLevels = {};
  bool _loggingOut = false;
  bool _deletingAccount = false;
  bool _savingLocation = false;
  bool _savingRadius = false;
  bool _savingSports = false;
  bool _savingIntention = false;
  bool _savingAvailability = false;
  bool _savingBio = false;
  bool _savingSkillLevels = false;
  bool _savingExperience = false;

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
        _emailVerificationEnabled = me.emailVerificationEnabled;
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
      MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: email)),
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

    setState(() => _savingLocation = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateLocation(result);
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, fallback: 'No se ha podido guardar tu ubicación.'),
          ),
        ),
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
        SnackBar(
          content: Text(
            friendlyError(
              e,
              fallback: 'No se ha podido guardar el radio de búsqueda.',
            ),
          ),
        ),
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
        SnackBar(
          content: Text(
            friendlyError(
              e,
              fallback: 'No se han podido guardar tus deportes.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingSports = false);
    }
  }

  /// Cuándo puede jugar. Es lo que decide si dos personas pueden llegar a
  /// coincidir, y hasta ahora la app no lo sabía en absoluto.
  Future<void> _changeAvailability() async {
    final current = _profile?.availability ?? WeeklyAvailability.empty;
    final chosen = await showModalBottomSheet<WeeklyAvailability>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AvailabilitySheet(initial: current),
    );
    if (chosen == null || !mounted) return;

    setState(() => _savingAvailability = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateAvailability(chosen);
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _savingAvailability = false);
    }
  }

  /// A qué viene. Antes esto solo se preguntaba en el onboarding y, peor,
  /// la frase elegida se guardaba como la bio.
  Future<void> _changeIntention() async {
    final chosen = await showModalBottomSheet<_IntentionChoice>(
      context: context,
      builder: (_) => _IntentionSheet(initial: _profile?.intention),
    );
    if (chosen == null || !mounted) return;

    setState(() => _savingIntention = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateIntention(chosen.value);
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, fallback: 'No se han podido guardar los cambios.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingIntention = false);
    }
  }

  /// La descripción libre. Hasta ahora no se podia editar en ningun sitio.
  Future<void> _changeBio() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BioSheet(initial: _profile?.bio ?? ''),
    );
    if (chosen == null || !mounted) return;

    setState(() => _savingBio = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateBio(chosen);
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(
              e,
              fallback: 'No se ha podido guardar tu descripción.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingBio = false);
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

    setState(() => _savingSkillLevels = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateSkillLevels(chosen);
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, fallback: 'No se ha podido guardar tu nivel.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingSkillLevels = false);
    }
  }

  /// Señales de confianza estructuradas (años jugando, club, logros) — ver
  /// status.md, "Reposicionamiento de producto".
  Future<void> _changeExperience() async {
    final chosen = await showModalBottomSheet<_ExperienceResult>(
      context: context,
      builder: (sheetContext) => _ExperienceSheet(
        sports: _profile?.sports ?? const [],
        initialYearsPlaying: _profile?.yearsPlaying,
        initialClub: _profile?.club ?? '',
        initialAvgPaceMinPerKm: _profile?.avgPaceMinPerKm,
        initialAvgDistanceKm: _profile?.avgDistanceKm,
        initialAchievements: _profile?.achievements ?? const [],
      ),
    );
    if (chosen == null || !mounted) return;

    setState(() => _savingExperience = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateExperience(
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
        SnackBar(
          content: Text(
            friendlyError(
              e,
              fallback: 'No se ha podido guardar tu experiencia.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingExperience = false);
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

  /// Borrar la cuenta cierra sesión a la fuerza: el token que hay guardado
  /// apunta a un usuario que ya no existe, así que dejarlo puesto sólo
  /// sirve para que la siguiente pantalla falle con un 401 raro.
  Future<void> _confirmDeleteAccount() async {
    final confirmed = await confirmDeleteAccount(context);
    if (!confirmed || !mounted) return;

    setState(() => _deletingAccount = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.deleteAccount();
      await TokenStorage.clear();
      if (!mounted) return;
      context.go(AppRoutes.welcome);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);

    // Antes de nada: el endpoint de baja va autenticado, así que tiene que
    // salir mientras el token de sesión sigue guardado. Si no, quien entrara
    // después en este móvil recibiría las notificaciones de esta cuenta.
    await PushService.unregisterCurrentDevice();

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
        .map(
          (s) => _skillLevels[s] == null
              ? null
              : '${s.label}: ${_skillLevels[s]!.label}',
        )
        .whereType<String>()
        .toList();
    return parts.isEmpty ? 'Sin definir' : parts.join(' · ');
  }

  String get _experienceSubtitle {
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
                            : _emailVerificationEnabled
                            ? Icons.mark_email_unread_outlined
                            : Icons.email_outlined,
                        iconBackground: _emailVerified
                            ? context.colors.secondaryContainer
                            : context.colors.tertiaryContainer,
                        iconColor: _emailVerified
                            ? context.colors.onSecondaryContainer
                            : context.colors.onTertiaryContainer,
                        title: 'Email',
                        // Con la verificación apagada en el servidor la
                        // fila es sólo informativa: enseñar "sin verificar"
                        // y dejar tocarlo llevaría a un error que no depende
                        // de quien lo toca.
                        subtitle: !_emailVerificationEnabled
                            ? _email!
                            : _emailVerified
                            ? '${_email!}\nVerificado'
                            : '${_email!}\nSin verificar — toca para confirmarlo',
                        onTap: (_emailVerified || !_emailVerificationEnabled)
                            ? null
                            : _verifyEmail,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: context.colors.outline,
                            ),
                      onTap: _savingRadius ? null : _changeRadius,
                    ),
                    // Sin fila de "Deportes" mientras la app sea de uno solo:
                    // era la única puerta que quedaba para marcar correr, y
                    // dejarla abierta significa perfiles que dicen que corren
                    // en una app donde correr ya no existe. Vuelve sola en
                    // cuanto haya un segundo deporte (ver `app_sports.dart`).
                    if (!isSingleSportApp)
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
                      icon: Icons.schedule,
                      iconBackground: context.colors.tertiaryContainer,
                      iconColor: context.colors.onTertiaryContainer,
                      title: 'Disponibilidad',
                      // Sin resumen debajo: `summary` sale como "Tarde LMXJ ·
                      // mañana SD", que hay que descifrar. La rejilla entera
                      // está a un toque y se lee de un vistazo.
                      subtitle: null,
                      trailing: _savingAvailability
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: context.colors.outline,
                            ),
                      onTap: _savingAvailability ? null : _changeAvailability,
                    ),
                    _SettingsRow(
                      icon: Icons.flag_outlined,
                      iconBackground: context.colors.tertiaryContainer,
                      iconColor: context.colors.onTertiaryContainer,
                      title: 'A qué vienes',
                      subtitle: _profile?.intention?.label ?? 'Sin definir',
                      trailing: _savingIntention
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: context.colors.outline,
                            ),
                      onTap: _savingIntention ? null : _changeIntention,
                    ),
                    _SettingsRow(
                      icon: Icons.notes_outlined,
                      iconBackground: context.colors.tertiaryContainer,
                      iconColor: context.colors.onTertiaryContainer,
                      title: 'Descripción',
                      subtitle: (_profile?.bio ?? '').trim().isEmpty
                          ? 'Sin escribir'
                          : _profile!.bio!.trim(),
                      trailing: _savingBio
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: context.colors.outline,
                            ),
                      onTap: _savingBio ? null : _changeBio,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                      title: 'Experiencia',
                      subtitle: _experienceSubtitle,
                      trailing: _savingExperience
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: context.colors.outline,
                            ),
                      onTap: _savingExperience ? null : _changeExperience,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: context.colors.outline,
                            ),
                      onTap: _loggingOut ? null : _confirmLogout,
                    ),
                    // Debajo de cerrar sesión y en su propio grupo: es la
                    // acción más destructiva de la app, no debería quedar
                    // pegada a nada que se toque a menudo.
                    _SettingsRow(
                      icon: Icons.delete_forever_outlined,
                      iconBackground: context.colors.error.withValues(
                        alpha: 0.12,
                      ),
                      iconColor: context.colors.error,
                      title: 'Borrar mi cuenta',
                      titleColor: context.colors.error,
                      subtitle: 'No se puede deshacer',
                      trailing: _deletingAccount
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: context.colors.outline,
                            ),
                      onTap: _deletingAccount ? null : _confirmDeleteAccount,
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
              'Hasta dónde buscamos gente, desde tu ubicación.',
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
              'A qué juegas. Determina a quién ves en Descubrir y '
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
            const SizedBox(height: 16),
            for (final sport in widget.sports) ...[
              // El nombre del deporte solo cuando hay mas de uno que
              // distinguir: con la app en tenis, un encabezado "Tenis" encima
              // de los cuatro niveles no separa nada de nada.
              if (widget.sports.length > 1) ...[
                Text(sport.label, style: context.textStyles.titleSmall),
                const SizedBox(height: 8),
              ],
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

class _ExperienceResult {
  final int? yearsPlaying;
  final String? club;
  final double? avgPaceMinPerKm;
  final double? avgDistanceKm;
  final List<String> achievements;

  const _ExperienceResult({
    required this.yearsPlaying,
    required this.club,
    required this.avgPaceMinPerKm,
    required this.avgDistanceKm,
    required this.achievements,
  });
}

/// Cabecera de seccion con el icono del deporte, para cuando hay campos de
/// los dos seguidos. Con un solo deporte no se usa: seria ruido.
Widget _sportHeaderRow(BuildContext context, Sport sport) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(sportIcon(sport), size: 18, color: context.colors.primary),
        const SizedBox(width: 8),
        Text(
          sport.label,
          style: context.textStyles.titleSmall?.copyWith(
            color: context.colors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: context.colors.outlineVariant)),
      ],
    ),
  );
}

class _ExperienceSheet extends StatefulWidget {
  final List<Sport> sports;
  final int? initialYearsPlaying;
  final String initialClub;
  final double? initialAvgPaceMinPerKm;
  final double? initialAvgDistanceKm;
  final List<String> initialAchievements;

  const _ExperienceSheet({
    required this.sports,
    required this.initialYearsPlaying,
    required this.initialClub,
    required this.initialAvgPaceMinPerKm,
    required this.initialAvgDistanceKm,
    required this.initialAchievements,
  });

  @override
  State<_ExperienceSheet> createState() => _ExperienceSheetState();
}

class _ExperienceSheetState extends State<_ExperienceSheet> {
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
      setState(
        () => _error = 'Máximo $_maxAchievementLength caracteres por logro',
      );
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
      setState(
        () =>
            _error = 'El club no puede superar los $_maxClubLength caracteres',
      );
      return;
    }
    Navigator.of(context).pop(
      _ExperienceResult(
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
    // Misma separacion que en el onboarding: con los dos deportes, los
    // cuatro campos caian seguidos y sin decir cual era de que.
    final playsBoth = playsTennis && playsRunning;

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
              Text('Experiencia', style: context.textStyles.titleMedium),
              const SizedBox(height: 16),
              if (playsTennis) ...[
                if (playsBoth) _sportHeaderRow(context, Sport.tennis),
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
                if (playsBoth) _sportHeaderRow(context, Sport.running),
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

/// Envuelve la elección para poder distinguir "he elegido no decirlo"
/// (`value == null`) de "he cerrado la hoja sin tocar nada" (la hoja
/// devuelve null a secas). Sin esto no habría forma de retirar la respuesta.
class _IntentionChoice {
  final Intention? value;
  const _IntentionChoice(this.value);
}

class _IntentionSheet extends StatefulWidget {
  final Intention? initial;
  const _IntentionSheet({required this.initial});

  @override
  State<_IntentionSheet> createState() => _IntentionSheetState();
}

class _IntentionSheetState extends State<_IntentionSheet> {
  Intention? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  /// Fila seleccionable. No se usa `RadioListTile` porque su `groupValue`
  /// está deprecado desde Flutter 3.32 y además el resto de la app ya elige
  /// con tarjetas marcadas por un check, no con radios.
  Widget _choice({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: selected
          ? Icon(Icons.check_circle, color: context.colors.primary)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('A qué vienes', style: context.textStyles.titleLarge),
            const SizedBox(height: 16),
            for (final option in Intention.values)
              _choice(
                icon: option.icon,
                title: option.label,
                subtitle: option.description,
                selected: _selected == option,
                onTap: () => setState(() => _selected = option),
              ),
            _choice(
              icon: Icons.remove_circle_outline,
              title: 'Prefiero no decirlo',
              selected: _selected == null,
              onTap: () => setState(() => _selected = null),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_IntentionChoice(_selected)),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BioSheet extends StatefulWidget {
  final String initial;
  const _BioSheet({required this.initial});

  @override
  State<_BioSheet> createState() => _BioSheetState();
}

class _BioSheetState extends State<_BioSheet> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final text = _ctrl.text.trim();
    // El mismo tope que valida el backend. Se comprueba al guardar y no con
    // un `maxLength`, que dibujaría un contador permanente bajo el campo —
    // ruido visual que ya se quitó del resto de la app a petición tuya.
    if (text.length > 500) {
      setState(() => _error = 'Máximo 500 caracteres (llevas ${text.length}).');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Deja sitio al teclado: sin esto el campo queda debajo y no se ve lo
      // que se escribe.
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sobre ti', style: context.textStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Añade cualquier información que pueda interesarle a tu futuro compañero.',
            style: context.textStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            minLines: 3,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  'Soy una persona entusiasmada por el tenis. '
                  'Busco a alguien para jugar a menudo.',
              errorText: _error,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
    );
  }
}

class _AvailabilitySheet extends StatefulWidget {
  final WeeklyAvailability initial;
  const _AvailabilitySheet({required this.initial});

  @override
  State<_AvailabilitySheet> createState() => _AvailabilitySheetState();
}

class _AvailabilitySheetState extends State<_AvailabilitySheet> {
  late WeeklyAvailability _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Disponibilidad',
              style: context.textStyles.titleLarge,
            ),
            const SizedBox(height: 16),
            AvailabilityPicker(
              value: _selected,
              onChanged: (v) => setState(() => _selected = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

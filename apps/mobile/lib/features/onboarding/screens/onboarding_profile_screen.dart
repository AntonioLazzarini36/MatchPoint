import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/location/location_result.dart';
import '../../../core/network/api.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/ui/profile/photo_grid_editor.dart';
import '../../auth/models/auth_response.dart';
import '../../auth/models/login_request.dart';
import '../../auth/models/register_request.dart';
import '../../auth/services/auth_service.dart';
import '../models/update_profile_request.dart';
import '../onboarding_controller.dart';
import '../services/profile_service.dart';
import '../../discovery/models/skill_level.dart';
import '../../discovery/models/sport.dart';

import 'package:match_point/core/ui/widgets/onboarding/onboarding_step_scaffold.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_profile_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_skill_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_preferences_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_location_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_photo_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_preview_step.dart';
import 'package:match_point/features/onboarding/models/gender.dart';
import 'package:match_point/core/ui/profile/photo_crop_preview.dart';
import 'package:match_point/features/auth/screens/email_verification_screen.dart';
import 'package:match_point/core/ui/profile/photo_source_sheet.dart';

class _PickedPhoto {
  final Uint8List bytes;
  final String filename;
  final String contentType;

  const _PickedPhoto({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });
}

class OnboardingProfileScreen extends StatefulWidget {
  /// Null cuando se llega aquí ya logueado (cuenta a medias de un intento
  /// interrumpido, ver el redirect de `router.dart`) — en ese caso el
  /// paso final solo termina de rellenar el perfil, no vuelve a registrar.
  final String? email;
  final String? password;

  const OnboardingProfileScreen({super.key, this.email, this.password});

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  static const _totalPages = 6;
  static const _skillStepIndex = 1;
  static const _locationStepIndex = 3;
  static const _photoStepIndex = 4;
  static const _previewStepIndex = 5;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Empieza vacío a propósito: con los dos marcados desde el arranque no
  // quedaba claro qué habías elegido vos y qué no (feedback del usuario,
  // 2026-08-02) — mejor forzar una elección explícita, validada abajo.
  final Set<String> _selectedSports = {};
  String _goal = 'Jugar por nivel';
  double _radiusKm = 15;
  LocationResult? _selectedLocation;

  // Preferencias de a quien mostrar en Discovery mas adelante (ver
  // onboarding_preferences_step.dart) - independientes de _selectedSports
  // (lo que el usuario juega). _sportsWanted vacio significa "todavia no
  // lo toco" y cae a los mismos deportes que juega como default sensato
  // (ver _effectiveSportsWanted abajo), sin necesitar sincronizarlo a
  // mano en cada cambio de _selectedSports.
  RangeValues _ageRange = const RangeValues(18, 60);
  final Set<Sport> _sportsWanted = {};
  Gender? _gender;
  Gender? _genderPreference;

  Map<Sport, SkillLevel> _skillLevels = {};
  // Tenis: años jugando + club. Correr: ritmo/distancia media. Se
  // muestran condicionalmente en OnboardingSkillStep según los deportes
  // elegidos arriba — ver status.md, "Reposicionamiento de producto".
  int? _yearsPlaying;
  String _club = '';
  double? _avgPaceMinPerKm;
  double? _avgDistanceKm;
  List<String> _achievements = [];

  final displayNameCtrl = TextEditingController();
  DateTime? birthDate;

  final List<_PickedPhoto> _localPhotos = [];
  bool _photoBusy = false;
  String? _photoError;

  late final OnboardingController controller;
  late final AuthService authService;

  @override
  void initState() {
    super.initState();
    controller = OnboardingController(ProfileService(Api.client));
    authService = AuthService(Api.client);
    _skipIfHasProfile();
  }

  Future<void> _skipIfHasProfile() async {
    final has = await controller.hasProfile();
    if (has && mounted) context.go(AppRoutes.shell);
  }

  @override
  void dispose() {
    _pageController.dispose();
    displayNameCtrl.dispose();
    super.dispose();
  }

  String? _sportToBackend(String uiSport) {
    switch (uiSport) {
      case 'Tenis':
        return 'TENNIS';
      case 'Correr':
        return 'RUNNING';
      default:
        return null;
    }
  }

  List<String> _sportsForBackend() {
    return _selectedSports.map(_sportToBackend).whereType<String>().toList();
  }

  List<Sport> _sportsAsEnum() {
    return _sportsForBackend().map(SportApi.fromApi).toList();
  }

  Set<Sport> get _effectiveSportsWanted =>
      _sportsWanted.isEmpty ? _sportsAsEnum().toSet() : _sportsWanted;

  /// El paso de nivel/credenciales es el único realmente opcional del
  /// wizard — en vez de escribir "(opcional)" en la pantalla, el botón
  /// mismo dice "Saltar" mientras no haya nada cargado, y pasa a
  /// "Siguiente" en cuanto tocás algo (feedback del usuario, 2026-08-02).
  bool get _hasCredentialsFilled {
    return _yearsPlaying != null ||
        _club.isNotEmpty ||
        _avgPaceMinPerKm != null ||
        _avgDistanceKm != null ||
        _achievements.isNotEmpty;
  }

  bool get _isSkillStepEmpty => _skillLevels.isEmpty && !_hasCredentialsFilled;

  int? get _age {
    final b = birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var a = now.year - b.year;
    final hadBirthday =
        (now.month > b.month) || (now.month == b.month && now.day >= b.day);
    if (!hadBirthday) a--;
    return a;
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = birthDate ?? DateTime(now.year - 25, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year - 16, now.month, now.day),
    );

    if (picked != null) setState(() => birthDate = picked);
  }

  static const _maxDisplayNameLength = 30;
  static const _maxClubLength = 60;
  static const _maxAchievementLength = 80;

  Future<void> _goNextOrFinish() async {
    if (_currentPage == 0) {
      final name = displayNameCtrl.text.trim();
      if (name.isEmpty) {
        controller.setError('Display name is required');
        return;
      }
      if (name.length > _maxDisplayNameLength) {
        controller.setError(
          'El nombre no puede superar los $_maxDisplayNameLength caracteres',
        );
        return;
      }
      if (birthDate == null) {
        controller.setError('Birth date is required');
        return;
      }
      if (_selectedSports.isEmpty) {
        controller.setError('Elige al menos un deporte');
        return;
      }
    }

    if (_currentPage == _skillStepIndex) {
      if (_club.length > _maxClubLength) {
        controller.setError(
          'El club no puede superar los $_maxClubLength caracteres',
        );
        return;
      }
      if (_achievements.any((a) => a.length > _maxAchievementLength)) {
        controller.setError(
          'Cada logro no puede superar los $_maxAchievementLength caracteres',
        );
        return;
      }
    }

    if (_currentPage == _locationStepIndex && _selectedLocation == null) {
      controller.setError(
        'Elige tu ubicación para poder mostrarte gente cerca tuyo',
      );
      return;
    }

    if (_currentPage < _previewStepIndex) {
      controller.setError(null);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // _currentPage == _previewStepIndex: nada se manda al backend hasta
    // este último paso — antes se creaba todo directo desde el paso de
    // fotos, ahora hay un preview de por medio para que confirmes cómo
    // se ve antes de que se cree de verdad (pedido del usuario,
    // 2026-08-03).
    await _completeRegistration();
  }

  /// Nada existe en el backend hasta este punto: aquí se crea (o se
  /// recupera, si un intento anterior falló a medias) el usuario, se
  /// guarda el perfil, y se suben todas las fotos elegidas — uno detrás
  /// de otro, disparado por el único "Comenzar" final del wizard.
  Future<void> _completeRegistration() async {
    controller.setError(null);
    controller.setLoading(true);

    try {
      final email = widget.email;
      final password = widget.password;

      if (email != null && password != null) {
        AuthResponse tokens;
        try {
          tokens = await authService.register(
            RegisterRequest(email: email, password: password),
          );
        } catch (_) {
          // Recuperación: si un intento anterior ya llegó a crear el
          // usuario (p.ej. se cortó la conexión justo después del
          // register) o hay una carrera rara con el check de
          // disponibilidad, intentar login con las mismas credenciales
          // es la forma segura de continuar en vez de quedar atascado.
          tokens = await authService.login(
            LoginRequest(email: email, password: password),
          );
        }
        await TokenStorage.saveToken(tokens.accessToken);
        await TokenStorage.saveRefreshToken(tokens.refreshToken);
      }

      final req = UpdateProfileRequest(
        displayName: displayNameCtrl.text.trim(),
        birthDate: _formatDate(birthDate!),
        city: _selectedLocation?.displayName,
        bio: _goal,
        sports: _sportsForBackend(), // ✅ solo Tenis/Correr
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
      );
      await controller.service.updateProfile(req);
      // Aparte de `updateProfile` porque el género tiene que poder
      // mandarse como null explícito ("prefiero no decirlo") y
      // `UpdateProfileRequest` omite los nulos — ver `updateGender`.
      await controller.service.updateGender(_gender);
      await controller.service.updateDiscoveryRadius(_radiusKm.round());
      await controller.service.updatePreferences(
        ageMin: _ageRange.start.round(),
        ageMax: _ageRange.end.round(),
        sportsWanted: _effectiveSportsWanted.toList(),
        genderPreference: _genderPreference,
      );

      final mySports = _sportsAsEnum().toSet();
      final levelsForMySports = Map<Sport, SkillLevel>.fromEntries(
        _skillLevels.entries.where((e) => mySports.contains(e.key)),
      );
      if (levelsForMySports.isNotEmpty) {
        await controller.service.updateSkillLevels(levelsForMySports);
      }
      if (_hasCredentialsFilled) {
        await controller.service.updateCredentials(
          yearsPlaying: _yearsPlaying,
          club: _club.isEmpty ? null : _club,
          avgPaceMinPerKm: _avgPaceMinPerKm,
          avgDistanceKm: _avgDistanceKm,
          achievements: _achievements,
        );
      }

      for (final photo in _localPhotos) {
        await controller.service.uploadPhoto(
          bytes: photo.bytes,
          filename: photo.filename,
          contentType: photo.contentType,
        );
      }

      if (!mounted) return;

      // Verificar el email va justo aquí y no escondido en Ajustes: es el
      // único momento en que alguien tiene el correo a mano y entiende por
      // qué se lo pedimos. Es saltable a propósito — no verificar no
      // bloquea nada todavía, y plantar un muro nada más registrarse es la
      // forma más rápida de que alguien no llegue a probar la app.
      // Se pregunta al servidor si la verificación está activa antes de
      // enseñar la pantalla. Sin un dominio de correo propio, el proveedor
      // sólo entrega al titular de la cuenta, así que a cualquier otro le
      // saldría un fallo de envío justo al terminar de registrarse — la
      // peor primera impresión posible. Si la consulta falla, no se enseña:
      // ante la duda, mejor no meter a nadie en un callejón sin salida.
      var verificationEnabled = false;
      try {
        verificationEnabled =
            (await controller.service.getMe()).emailVerificationEnabled;
      } catch (_) {
        // se queda en false
      }
      if (!mounted) return;

      if (email != null && verificationEnabled) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: email),
          ),
        );
      }

      if (mounted) context.go(AppRoutes.shell);
    } catch (e) {
      controller.setError('No se pudo completar el registro: $e');
    } finally {
      if (mounted) controller.setLoading(false);
    }
  }

  /// Varias de una tacada: rellenar el perfil foto a foto (elegir,
  /// recortar, confirmar, repetir) es lo primero que hace alguien recién
  /// llegado, y de una en una se hace eterno.
  Future<void> _addOnboardingPhotos() async {
    final remaining = PhotoGridEditor.maxPhotos - _localPhotos.length;
    if (remaining <= 0) {
      setState(
        () => _photoError = 'Máximo ${PhotoGridEditor.maxPhotos} fotos.',
      );
      return;
    }

    final picked = await pickPhotos(context, limit: remaining);
    if (picked.isEmpty || !mounted) return;

    setState(() {
      _photoBusy = true;
      _photoError = null;
    });

    try {
      final originals = <Uint8List>[];
      for (final file in picked) {
        originals.add(await file.readAsBytes());
      }
      if (!mounted) return;
      // Recorte a 16:9 con vista previa: la app enseña las fotos siempre
      // en horizontal, así que es mejor que el usuario vea el encuadre
      // final ahora que descubra después que le cortó la cabeza.
      final cropped = await showPhotoCropPreview(
        context,
        originals: originals,
      );
      if (cropped == null || cropped.isEmpty || !mounted) return;
      setState(() {
        for (final bytes in cropped) {
          _localPhotos.add(
            _PickedPhoto(
              bytes: bytes,
              // El recorte re-codifica a PNG (ver landscape_crop.dart), así
              // que el nombre/tipo originales ya no describen los bytes.
              filename: '${DateTime.now().microsecondsSinceEpoch}.png',
              contentType: 'image/png',
            ),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _photoError = 'No se pudieron leer las fotos: $e');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _deleteOnboardingPhoto(int index) {
    if (_localPhotos.length <= 1) return;
    setState(() {
      _photoError = null;
      _localPhotos.removeAt(index);
    });
  }

  /// En la primera página, "atrás" ya no tiene otra página del wizard a
  /// la que volver — significa abandonar el registro/onboarding entero,
  /// así que confirma antes (pedido del usuario, 2026-08-03: es "cambiar
  /// a otra lógica", no un simple paso atrás). En el resto de páginas
  /// sigue siendo solo navegación normal dentro del wizard, sin preguntar
  /// nada.
  Future<void> _goBack() async {
    if (_currentPage > 0) {
      await _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir del registro?'),
        content: const Text(
          'Vas a volver a la pantalla de login/registro. Nada de lo que '
          'completaste todavía se guardó — no se pierde ningún dato ya '
          'creado, pero tendrás que volver a empezar el registro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Por si esta pantalla se alcanzó ya logueado (cuenta a medias de un
    // intento anterior, ver el comentario de `widget.email` arriba) —
    // sin esto, `router.dart` redirige de vuelta a /onboarding en vez de
    // dejar ver login/registro, porque sigue habiendo un token válido.
    await TokenStorage.clear();
    if (mounted) context.go(AppRoutes.onboardingAuth);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final onPhotoStepWithoutPhoto =
            _currentPage == _photoStepIndex && _localPhotos.isEmpty;

        return OnboardingStepScaffold(
          currentPage: _currentPage,
          totalPages: _totalPages,
          onBack: _goBack,
          // Nada existe todavía hasta completar el wizard entero — no
          // hay a dónde "saltar" (el redirect global mandaría de vuelta
          // aquí igualmente).
          onSkip: null,
          onNext: (controller.isLoading || onPhotoStepWithoutPhoto)
              ? null
              : _goNextOrFinish,
          isLoading: controller.isLoading,
          nextLabel: _currentPage == _previewStepIndex
              ? 'Confirmar y crear perfil'
              : _currentPage == _photoStepIndex
              ? 'Ver preview'
              : (_currentPage == _skillStepIndex && _isSkillStepEmpty
                    ? 'Saltar'
                    : 'Siguiente'),
          errorText: controller.error,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: [
              OnboardingProfileStep(
                displayNameCtrl: displayNameCtrl,
                birthDate: birthDate,
                onPickBirthDate: _pickBirthDate,
                birthDateLabel: birthDate == null
                    ? 'Select date'
                    : _formatDate(birthDate!),
                gender: _gender,
                onGenderChanged: (g) => setState(() => _gender = g),
                selectedSports: _selectedSports,
                onSportToggle: (sport, selected) {
                  setState(() {
                    if (selected) {
                      _selectedSports.add(sport);
                    } else {
                      _selectedSports.remove(sport);
                    }
                  });
                },
                onNameSubmitted: _goNextOrFinish,
              ),
              OnboardingSkillStep(
                sports: _sportsAsEnum(),
                skillLevels: _skillLevels,
                onSkillLevelsChanged: (levels) =>
                    setState(() => _skillLevels = levels),
                yearsPlaying: _yearsPlaying,
                onYearsPlayingChanged: (v) =>
                    setState(() => _yearsPlaying = v),
                club: _club,
                onClubChanged: (v) => setState(() => _club = v),
                avgPaceMinPerKm: _avgPaceMinPerKm,
                onAvgPaceMinPerKmChanged: (v) =>
                    setState(() => _avgPaceMinPerKm = v),
                avgDistanceKm: _avgDistanceKm,
                onAvgDistanceKmChanged: (v) =>
                    setState(() => _avgDistanceKm = v),
                achievements: _achievements,
                onAchievementsChanged: (v) =>
                    setState(() => _achievements = v),
                onFieldSubmitted: _goNextOrFinish,
              ),
              OnboardingPreferencesStep(
                goal: _goal,
                onGoalChanged: (g) => setState(() => _goal = g),
                ageRange: _ageRange,
                onAgeRangeChanged: (v) => setState(() => _ageRange = v),
                genderPreference: _genderPreference,
                onGenderPreferenceChanged: (v) =>
                    setState(() => _genderPreference = v),
              ),
              OnboardingLocationStep(
                location: _selectedLocation,
                onLocationChanged: (loc) =>
                    setState(() => _selectedLocation = loc),
                radiusKm: _radiusKm,
                onRadiusChanged: (v) => setState(() => _radiusKm = v),
              ),
              OnboardingPhotoStep(
                photos: _localPhotos.map((p) => p.bytes).toList(),
                busy: _photoBusy,
                error: _photoError,
                onAdd: _addOnboardingPhotos,
                onDelete: _deleteOnboardingPhoto,
              ),
              OnboardingPreviewStep(
                photos: _localPhotos.map((p) => p.bytes).toList(),
                displayName: displayNameCtrl.text.trim(),
                age: _age,
                city: _selectedLocation?.displayName,
                bio: _goal,
                sports: _sportsAsEnum(),
                skillLevels: _skillLevels,
                yearsPlaying: _yearsPlaying,
                club: _club.isEmpty ? null : _club,
                avgPaceMinPerKm: _avgPaceMinPerKm,
                avgDistanceKm: _avgDistanceKm,
                achievements: _achievements,
              ),
            ],
          ),
        );
      },
    );
  }
}

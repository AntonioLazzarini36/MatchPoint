import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
import 'package:match_point/core/ui/widgets/onboarding/onboarding_goal_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_location_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_photo_step.dart';

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
  static const _totalPages = 5;
  static const _skillStepIndex = 1;
  static const _photoStepIndex = 4;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Empieza vacío a propósito: con los dos marcados desde el arranque no
  // quedaba claro qué habías elegido vos y qué no (feedback del usuario,
  // 2026-08-02) — mejor forzar una elección explícita, validada abajo.
  final Set<String> _selectedSports = {};
  String _goal = 'Jugar por nivel';
  double _radiusKm = 15;
  LocationResult? _selectedLocation;

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

  Future<void> _goNextOrFinish() async {
    if (_currentPage == 0) {
      final name = displayNameCtrl.text.trim();
      if (name.isEmpty) {
        controller.setError('Display name is required');
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

    if (_currentPage < _photoStepIndex) {
      controller.setError(null);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // _currentPage == _photoStepIndex: el botón solo llega aquí activo si
    // ya hay al menos 1 foto local (ver `onNext` en build()).
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
      await controller.service.updateDiscoveryRadius(_radiusKm.round());

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

      if (mounted) context.go(AppRoutes.shell);
    } catch (e) {
      controller.setError('No se pudo completar el registro: $e');
    } finally {
      if (mounted) controller.setLoading(false);
    }
  }

  Future<void> _addOnboardingPhoto() async {
    if (_localPhotos.length >= PhotoGridEditor.maxPhotos) {
      setState(
        () => _photoError = 'Máximo ${PhotoGridEditor.maxPhotos} fotos.',
      );
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _photoBusy = true;
      _photoError = null;
    });

    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _localPhotos.add(
          _PickedPhoto(
            bytes: bytes,
            filename: picked.name,
            contentType:
                picked.mimeType ?? guessPhotoContentType(picked.name),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _photoError = 'No se pudo leer la foto: $e');
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

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
          nextLabel: _currentPage == _photoStepIndex
              ? 'Comenzar'
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
              ),
              OnboardingGoalStep(
                goal: _goal,
                onGoalChanged: (g) => setState(() => _goal = g),
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
                onAdd: _addOnboardingPhoto,
                onDelete: _deleteOnboardingPhoto,
              ),
            ],
          ),
        );
      },
    );
  }
}

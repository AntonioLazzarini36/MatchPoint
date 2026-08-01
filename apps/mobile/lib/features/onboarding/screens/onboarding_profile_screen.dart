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

import 'package:match_point/core/ui/widgets/onboarding/onboarding_step_scaffold.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_profile_step.dart';
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
  static const _totalPages = 4;
  static const _photoStepIndex = 3;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  final Set<String> _selectedSports = {'Tenis', 'Correr'};
  String _goal = 'Jugar por nivel';
  double _radiusKm = 15;
  LocationResult? _selectedLocation;

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
          nextLabel: _currentPage == _photoStepIndex ? 'Comenzar' : 'Siguiente',
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

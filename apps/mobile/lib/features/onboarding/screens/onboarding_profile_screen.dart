import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes.dart';
import '../../../core/network/api.dart';
import '../../../core/ui/profile/photo_grid_editor.dart';
import '../models/update_profile_request.dart';
import '../onboarding_controller.dart';
import '../services/profile_service.dart';

import 'package:match_point/core/ui/widgets/onboarding/onboarding_step_scaffold.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_profile_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_goal_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_location_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_photo_step.dart';

class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key});

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

  final displayNameCtrl = TextEditingController();
  DateTime? birthDate;

  List<String> _photos = [];
  bool _photoBusy = false;
  String? _photoError;

  late final OnboardingController controller;

  @override
  void initState() {
    super.initState();
    controller = OnboardingController(ProfileService(Api.client));
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
    if (_currentPage < 2) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_currentPage == 2) {
      final name = displayNameCtrl.text.trim();
      if (name.isEmpty) {
        controller.setError('Display name is required');
        return;
      }
      if (birthDate == null) {
        controller.setError('Birth date is required');
        return;
      }

      final req = UpdateProfileRequest(
        displayName: name,
        birthDate: _formatDate(birthDate!),
        city: 'Madrid',
        bio: _goal,
        photos: const [],
        sports: _sportsForBackend(), // ✅ solo Tenis/Correr
      );

      // El perfil se crea aquí (sin fotos) para que el paso siguiente ya
      // pueda subir alguna — POST /me/photos necesita un perfil existente.
      final ok = await controller.submitProfile(req);
      if (!ok || !mounted) return;

      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // _currentPage == _photoStepIndex: el botón solo llega aquí activo si
    // ya hay al menos 1 foto (ver `onNext` en build()).
    if (mounted) context.go(AppRoutes.shell);
  }

  Future<void> _addOnboardingPhoto() async {
    if (_photos.length >= PhotoGridEditor.maxPhotos) {
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
      final profile = await controller.service.uploadPhoto(
        bytes: bytes,
        filename: picked.name,
        contentType: picked.mimeType ?? guessPhotoContentType(picked.name),
      );
      if (!mounted) return;
      setState(() => _photos = profile.photos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _photoError = 'No se pudo subir la foto: $e');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _deleteOnboardingPhoto(String url) async {
    if (_photos.length <= 1) return;

    setState(() {
      _photoBusy = true;
      _photoError = null;
    });

    try {
      final profile = await controller.service.deletePhoto(url);
      if (!mounted) return;
      setState(() => _photos = profile.photos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _photoError = 'No se pudo borrar la foto: $e');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
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
            _currentPage == _photoStepIndex && _photos.isEmpty;

        return OnboardingStepScaffold(
          currentPage: _currentPage,
          totalPages: _totalPages,
          onBack: _goBack,
          // El paso de fotos es obligatorio: no se puede saltar desde ahí.
          onSkip: _currentPage == _photoStepIndex
              ? null
              : () => context.go(AppRoutes.shell),
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
                radiusKm: _radiusKm,
                onRadiusChanged: (v) => setState(() => _radiusKm = v),
              ),
              OnboardingPhotoStep(
                photos: _photos,
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

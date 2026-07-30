import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api.dart';
import '../../../core/ui/profile/photo_manager_sheet.dart';
import '../models/update_profile_request.dart';
import '../onboarding_controller.dart';
import '../services/profile_service.dart';

import 'package:match_point/core/ui/widgets/onboarding/onboarding_step_scaffold.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_profile_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_goal_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_location_step.dart';

class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final Set<String> _selectedSports = {'Tenis', 'Correr'};
  String _goal = 'Jugar por nivel';
  double _radiusKm = 15;

  final displayNameCtrl = TextEditingController();
  DateTime? birthDate;

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

    final ok = await controller.submitProfile(req);
    if (!ok || !mounted) return;

    // Foto obligatoria: el perfil ya existe (se acaba de crear arriba), así
    // que ya se puede subir. No se puede cerrar el sheet (ni tocando fuera,
    // ni con el botón atrás) hasta añadir al menos 1 foto.
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => PhotoManagerSheet(
        service: controller.service,
        initialPhotos: const [],
        requireAtLeastOne: true,
        onChanged: (_) {},
      ),
    );

    if (mounted) context.go(AppRoutes.shell);
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
        return OnboardingStepScaffold(
          currentPage: _currentPage,
          totalPages: 3,
          onBack: _goBack,
          onSkip: () => context.go(AppRoutes.shell),
          onNext: controller.isLoading ? null : _goNextOrFinish,
          isLoading: controller.isLoading,
          nextLabel: _currentPage == 2 ? 'Comenzar' : 'Siguiente',
          errorText: controller.error,
          child: PageView(
            controller: _pageController,
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
            ],
          ),
        );
      },
    );
  }
}

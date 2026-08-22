import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api.dart';
import '../../discovery/models/skill_level.dart';
import '../../discovery/models/sport.dart';
import '../../onboarding/models/profile.dart' as onboarding_profile;
import '../../onboarding/services/profile_service.dart';
import '../../../core/ui/profile/photo_manager_sheet.dart';
import '../../../core/ui/profile/profile_header_data.dart';
import '../../../core/ui/profile/profile_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileService service;

  bool loading = true;
  Object? error;
  ProfileHeaderData? data;
  onboarding_profile.Profile? profile;
  Map<Sport, SkillLevel> _skillLevels = {};
  String? myUserId;

  @override
  void initState() {
    super.initState();
    service = ProfileService(Api.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final me = await service.getMe();
      final p = me.profile;

      if (!mounted) return;

      myUserId = me.id;
      _skillLevels = me.skillLevels;

      if (p == null) {
        // No hay perfil todavia: renderizamos algo “vacio”
        setState(() {
          profile = null;
          data = const ProfileHeaderData(
            displayName: 'Sin perfil',
            photos: [],
            sports: [],
          );
          loading = false;
        });
        return;
      }

      setState(() {
        profile = p;
        data = ProfileHeaderData(
          displayName: p.displayName,
          age: p.age,
          city: p.city,
          bio: p.bio,
          intention: p.intention,
          availability: p.availability,
          photos: p.photos,
          sports: p.sports,
          skillLevels: _skillLevels,
          yearsPlaying: p.yearsPlaying,
          club: p.club,
          achievements: p.achievements,
          avgPaceMinPerKm: p.avgPaceMinPerKm,
          avgDistanceKm: p.avgDistanceKm,
        );
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  void _openSettings() => context.push(AppRoutes.settings);

  void _viewPublicProfile() {
    final userId = myUserId;
    if (userId == null) return;
    context.pushNamed(
      AppRoutes.userProfileName,
      pathParameters: {'userId': userId},
    );
  }

  void _openPhotoManager() {
    final currentProfile = profile;
    if (currentProfile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PhotoManagerSheet(
        service: service,
        initialPhotos: currentProfile.photos,
        onChanged: (photos) {
          setState(() {
            data = ProfileHeaderData(
              displayName: currentProfile.displayName,
              age: currentProfile.age,
              city: currentProfile.city,
              bio: currentProfile.bio,
              intention: currentProfile.intention,
              availability: currentProfile.availability,
              photos: photos,
              sports: currentProfile.sports,
              skillLevels: _skillLevels,
              yearsPlaying: currentProfile.yearsPlaying,
              club: currentProfile.club,
              achievements: currentProfile.achievements,
              avgPaceMinPerKm: currentProfile.avgPaceMinPerKm,
              avgDistanceKm: currentProfile.avgDistanceKm,
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudo cargar el perfil'),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            ),
          ),
        ),
      );
    }

    final d = data!;
    return Scaffold(
      body: ProfileView(
        data: d,
        sportsTitle: 'Mis Deportes',
        bioTitle: 'Sobre mi',
        showStats: true,
        showBottomButton: true,
        bottomButtonText: 'Ver mi perfil publico',
        onBottomButton: myUserId == null ? null : _viewPublicProfile,
        onSettings: _openSettings,
        onEdit: _openPhotoManager,
      ),
    );
  }
}

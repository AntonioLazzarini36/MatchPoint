import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api.dart';
import '../../discovery/models/level_verdict.dart';
import '../../discovery/models/skill_level.dart';
import '../../discovery/models/sport.dart';
import '../../onboarding/models/profile.dart' as onboarding_profile;
import '../../onboarding/services/profile_service.dart';
import '../../matches/services/matches_service.dart';
import '../../../core/ui/profile/photo_manager_sheet.dart';
import '../../../core/ui/profile/profile_header_data.dart';
import '../../../core/ui/profile/profile_view.dart';
import 'package:match_point/core/i18n/app_locale.dart';

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
  ProfileStats? _stats;

  @override
  void initState() {
    super.initState();
    service = ProfileService(Api.client);
    _load();
  }

  LevelVerdict? _levelVerdict;
  int _levelVotes = 0;

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

      // Las cifras salen de `/matches`, que ya trae `playedTogether` por
      // pareja. Se piden aparte y sin bloquear: si fallan, la fila
      // simplemente no aparece — un perfil sin estadisticas se lee bien, uno
      // que no carga por culpa de dos numeros no.
      unawaited(_loadStats());
      // Y lo que opinan de tu nivel, que sale de tu propia ficha pública: es
      // el mismo cálculo, y `/me` no lo trae. Aparte y sin bloquear, igual
      // que las cifras — verlo es útil, no poder abrir el perfil no.
      unawaited(_loadLevelVerdict(me.id));

      if (p == null) {
        // No hay perfil todavia: renderizamos algo “vacio”
        setState(() {
          profile = null;
          data = ProfileHeaderData(
            displayName: S.current.noProfile,
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
          levelVerdict: _levelVerdict,
          levelVotes: _levelVotes,
          isMine: true,
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

  /// Lo que opinan los demás de tu nivel. Se enseña **también en tu propio
  /// perfil** a propósito: es un aviso, no una medalla — si cinco personas
  /// dicen que te sobra nivel, lo que quieres es enterarte y corregirlo, no
  /// que sólo lo vean los demás.
  Future<void> _loadLevelVerdict(String userId) async {
    try {
      final mine = await service.getUserProfile(userId);
      if (!mounted) return;
      setState(() {
        _levelVerdict = mine.levelVerdict;
        _levelVotes = mine.levelVotes;
        final d = data;
        if (d != null) {
          data = d.copyWithVerdict(mine.levelVerdict, mine.levelVotes);
        }
      });
    } catch (_) {
      // sin veredicto, sin fila
    }
  }

  Future<void> _loadStats() async {
    try {
      final matches = await MatchesService(Api.client).fetchMatches();
      if (!mounted) return;
      setState(() {
        _stats = ProfileStats(
          partners: matches.length,
          played: matches.fold(0, (sum, m) => sum + m.playedTogether),
        );
      });
    } catch (_) {
      // sin cifras, sin fila
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
        appBar: AppBar(title: Text(S.current.profile)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(S.current.couldNotLoadProfile),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: Text(S.current.retry)),
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
        sportsTitle: S.current.mySports,
        bioTitle: S.current.aboutMe,
        showStats: true,
        stats: _stats,
        showBottomButton: true,
        bottomButtonText: S.current.seeMyPublicProfile,
        onBottomButton: myUserId == null ? null : _viewPublicProfile,
        onSettings: _openSettings,
        onEdit: _openPhotoManager,
      ),
    );
  }
}

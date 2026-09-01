import 'package:flutter/material.dart';
import 'package:match_point/core/network/api.dart';

import '../../../core/ui/dialogs/report_reason_dialog.dart';
import '../../../core/ui/profile/profile_header_data.dart';
import '../../../core/ui/profile/profile_view.dart';
import '../../onboarding/models/availability.dart';
import '../../onboarding/services/profile_service.dart';
import '../../discovery/models/discover_profile.dart';
import '../../../core/network/connection_error.dart';
import 'package:match_point/core/i18n/app_locale.dart';

class OtherProfileScreen extends StatefulWidget {
  final String userId;
  const OtherProfileScreen({super.key, required this.userId});

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  late final ProfileService service;

  bool loading = true;
  Object? error;
  ProfileHeaderData? data;
  bool _busy = false;

  /// Su historial: partidos jugados y ganados. Null si este backend todavía
  /// no los manda.
  int? _played;
  int? _won;

  @override
  void initState() {
    super.initState();
    service = ProfileService(Api.client);
    _load();
  }

  Future<void> _report() async {
    final reason = await showReportReasonDialog(context);
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.reportUser(widget.userId, reason);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(S.current.reportSent)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, fallback: S.current.couldNotSendReport),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final DiscoverProfile p = await service.getUserProfile(widget.userId);

      // Tu horario, para poder cruzarlo con el suyo y enseñar en qué huecos
      // coincidís. Se hace aquí y no en el servidor porque la ficha pública
      // no devuelve nada relativo a quien mira (ver `users/service.rs`), y
      // porque el cruce es un AND de dos enteros: no merece un endpoint.
      //
      // Si falla, la rejilla se enseña sin destacar nada. Perder el cruce es
      // mucho mejor que no poder abrir el perfil.
      var shared = WeeklyAvailability.empty;
      try {
        final me = await service.getMe();
        shared = me.profile?.availability.intersect(p.availability) ?? shared;
      } catch (_) {
        // se queda vacío
      }

      if (!mounted) return;
      setState(() {
        data = ProfileHeaderData(
          sharedAvailability: shared,
          levelVerdict: p.levelVerdict,
          levelVotes: p.levelVotes,
          displayName: p.displayName,
          age: p.age,
          city: p.city,
          bio: p.bio,
          intention: p.intention,
          availability: p.availability,
          photos: p.photos,
          sports: p.sports,
          skillLevels: p.skillLevels,
          yearsPlaying: p.yearsPlaying,
          club: p.club,
          achievements: p.achievements,
          avgPaceMinPerKm: p.avgPaceMinPerKm,
          avgDistanceKm: p.avgDistanceKm,
        );
        _played = p.playedCount;
        _won = p.wonCount;
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
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: Text(S.current.retry)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: ProfileView(
        data: data!,
        sportsTitle: S.current.sports,
        bioTitle: S.current.aboutYou,
        // Las cifras sólo si el servidor las manda: contra un backend viejo
        // llegan null y la fila desaparece, en vez de enseñar dos ceros que
        // se leerían como "no ha jugado nunca".
        showStats: _played != null,
        stats: _played == null
            ? null
            : ProfileStats(played: _played!, won: _won ?? 0),
        showBottomButton: false,
        onSettings: null,
        onEdit: null,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: S.current.report,
            onPressed: _busy ? null : _report,
          ),
        ],
      ),
    );
  }
}

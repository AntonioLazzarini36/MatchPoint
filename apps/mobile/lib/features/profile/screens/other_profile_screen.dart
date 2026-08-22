import 'package:flutter/material.dart';
import 'package:match_point/core/network/api.dart';

import '../../../core/ui/dialogs/report_reason_dialog.dart';
import '../../../core/ui/profile/profile_header_data.dart';
import '../../../core/ui/profile/profile_view.dart';
import '../../onboarding/services/profile_service.dart';
import '../../discovery/models/discover_profile.dart';
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
      messenger.showSnackBar(const SnackBar(content: Text('Reporte enviado')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('No se pudo reportar: $e')));
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

      if (!mounted) return;
      setState(() {
        data = ProfileHeaderData(
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _load,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: ProfileView(
        data: data!,
        sportsTitle: 'Deportes',
        bioTitle: 'Sobre',
        showStats: false,
        showBottomButton: false,
        onSettings: null,
        onEdit: null,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Reportar',
            onPressed: _busy ? null : _report,
          ),
        ],
      ),
    );
  }
}

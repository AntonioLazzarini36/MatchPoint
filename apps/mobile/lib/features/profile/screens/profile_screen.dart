import 'package:flutter/material.dart';

import '../../../core/network/api.dart';
import '../../onboarding/services/profile_service.dart';
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

      if (p == null) {
        // No hay perfil todavía: renderizamos algo “vacío”
        setState(() {
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
        data = ProfileHeaderData(
          displayName: p.displayName,
          age: p.age,
          city: p.city,
          bio: p.bio,
          photos: p.photos,
          sports: p.sports,
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
                const SizedBox(height: 8),
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

    final d = data!;
    return Scaffold(
      body: ProfileView(
        data: d,
        sportsTitle: 'Mis Deportes',
        bioTitle: 'Sobre mí',
        showStats: true,
        showBottomButton: true,
        bottomButtonText: 'Ver mi perfil público',
        onBottomButton: () {},
        onSettings: () {},
        onEdit: () {},
      ),
    );
  }
}
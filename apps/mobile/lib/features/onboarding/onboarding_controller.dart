import 'package:flutter/material.dart';
import './services/profile_service.dart';
import './models/update_profile_request.dart';

class OnboardingController extends ChangeNotifier {
  final ProfileService service;

  bool isLoading = false;
  String? error;

  OnboardingController(this.service);

  /// Un perfil "hecho" necesita, además de existir, al menos 1 foto — si
  /// no, se vuelve a mandar al usuario por el onboarding (o al paso de
  /// fotos) hasta que la tenga.
  Future<bool> hasProfile() async {
    try {
      final me = await service.getMe();
      final profile = me.profile;
      return profile != null && profile.photos.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> submitProfile(UpdateProfileRequest request) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      await service.updateProfile(request);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setError(String message) {
    error = message;
    notifyListeners();
  }
}

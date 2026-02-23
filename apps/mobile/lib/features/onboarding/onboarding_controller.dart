import 'package:flutter/material.dart';
import './services/profile_service.dart';
import './models/update_profile_request.dart';

class OnboardingController extends ChangeNotifier {
  final ProfileService service;

  bool isLoading = false;
  String? error;

  OnboardingController(this.service);

  Future<bool> hasProfile() async {
    try {
      final me = await service.getMe();
      return me.profile != null;
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'models/login_request.dart';
import 'models/register_request.dart';
import 'services/auth_service.dart';
import '../../core/push/push_service.dart';
import '../../core/storage/token_storage.dart';

class AuthController extends ChangeNotifier {
  final AuthService service;

  bool isLoading = false;
  String? error;

  AuthController(this.service);

  Future<bool> login(String email, String password) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final res = await service.login(
        LoginRequest(email: email, password: password),
      );
      await TokenStorage.saveToken(res.accessToken);
      await TokenStorage.saveRefreshToken(res.refreshToken);
      // Despues de guardar los tokens, no antes: el endpoint va autenticado.
      // Sin await a proposito — pedir el permiso de notificaciones no debe
      // retrasar la entrada a la app, y si falla no invalida el login.
      unawaited(PushService.registerCurrentDevice());

      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String email, String password) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final res = await service.register(
        RegisterRequest(email: email, password: password),
      );
      await TokenStorage.saveToken(res.accessToken);
      await TokenStorage.saveRefreshToken(res.refreshToken);
      // Despues de guardar los tokens, no antes: el endpoint va autenticado.
      // Sin await a proposito — pedir el permiso de notificaciones no debe
      // retrasar la entrada a la app, y si falla no invalida el login.
      unawaited(PushService.registerCurrentDevice());

      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setError(String? message) {
    error = message;
    notifyListeners();
  }
}

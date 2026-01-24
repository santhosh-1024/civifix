import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? firebaseUser;
  AppUser? profile;

  bool loading = true;

  AuthProvider() {
    _authService.authChanges().listen((user) async {
      firebaseUser = user;

      if (user != null) {
        profile = await _authService.getProfile(user.uid);
      } else {
        profile = null;
      }

      loading = false;
      notifyListeners();
    });
  }

  Future<void> registerEmail(String email, String password, String name) async {
    await _authService.registerEmail(email, password, name);
  }

  Future<void> loginEmail(String email, String password) async {
    await _authService.loginEmail(email, password);
  }

  Future<void> logout() async {
    await _authService.logout();
  }

  // Phone Auth
  Future<void> sendOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String message) onError,
  }) async {
    await _authService.sendOtp(
      phone: phone,
      onCodeSent: onCodeSent,
      onError: onError,
    );
  }

  Future<void> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    await _authService.verifyOtp(verificationId, otp);
  }
}

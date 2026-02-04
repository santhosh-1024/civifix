import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? firebaseUser;
  Map<String, dynamic>? profile;
  bool loading = true;

  // ✅ Renamed Constructor
  AppAuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    firebaseUser = user;

    if (user == null) {
      profile = null;
      loading = false;
      notifyListeners();
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      profile = snap.data();
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      profile = null;
    }

    loading = false;
    notifyListeners();
  }

  // 🔐 LOGIN
  Future<void> loginEmail(String email, String password) async {
    // Note: Exceptions are caught by the LoginScreen's try-catch block
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // authStateChanges listener handles the state update automatically
  }

  // 🔓 LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }
}
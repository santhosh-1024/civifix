import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'citizen/citizen_home_screen.dart';
import 'admin/admin_home_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.firebaseUser == null) {
      return const LoginScreen();
    }

    // role based redirect
    if (auth.profile?.role == "admin") {
      return AdminHomeScreen();
    } else {
      return const CitizenHomeScreen();
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_home_screen.dart';
import '../citizen/citizen_home_screen.dart';
import '../auth/login_screen.dart';

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("users").doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const CitizenHomeScreen();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final role = (data["role"] ?? "citizen").toString().toLowerCase();

        if (role == "admin") {
          return const AdminHomeScreen();
        }

        return const CitizenHomeScreen();
      },
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart'; // Added Fix
import '../../providers/auth_provider.dart';

import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../admin/admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminCodeController = TextEditingController();

  bool _adminModeEnabled = false;
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _adminCodeController.dispose();
    super.dispose();
  }

  Future<String?> _getEmailFromUsername(String username) async {
    final snap = await FirebaseFirestore.instance
        .collection("users")
        .where("username", isEqualTo: username)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final data = snap.docs.first.data();
    return (data["email"] ?? "").toString();
  }

  PageRoute _smoothRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ✅ FIX A: Normalize username
      final username = _usernameController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        setState(() {
          _error = "Please enter both username and password";
          _loading = false;
        });
        return;
      }

      // 1. Admin Logic (Bypasses Provider for secret code)
      if (_adminModeEnabled) {
        final secret = _adminCodeController.text.trim();
        if (secret == "CIVICFIX@ADMIN") {
          HapticFeedback.mediumImpact();
          setState(() => _loading = false); // Ensure loading stops
          Navigator.pushReplacement(
            context,
            _smoothRoute(const AdminHomeScreen()),
          );
          return;
        } else if (secret.isNotEmpty) {
          setState(() {
            _error = "Wrong Admin Code ❌";
            _loading = false;
          });
          return;
        }
      }

      // 2. Resolve Email
      final email = await _getEmailFromUsername(username);
      if (email == null) {
        setState(() {
          _error = "Account not found. Please create account.";
          _loading = false;
        });
        return;
      }

      // ✅ FIX 1: Using AuthProvider Login
      await context.read<AppAuthProvider>().loginEmail(email, password);

      // ✅ FIX 3: Verification Logic after Provider Login
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = "Email not verified ❌\nPlease verify your email first.";
          _loading = false;
        });
        return;
      }

      // ✅ FIX B: Reset loading on success
      setState(() => _loading = false);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login successful ✅")));

      // ✅ FIX 2: Removed Manual Citizen Navigation (handled by AuthWrapper)
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.code == "wrong-password"
            ? "Wrong password ❌"
            : (e.message ?? "Login failed");
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Something went wrong";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _PremiumGradientBackground(),
          _FloatingBlobs(controller: _bgController),
          _ParticlesLayer(controller: _bgController),
          SafeArea(
            child: ScrollConfiguration(
              behavior: const _BouncyScrollBehavior(),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 22),
                        _buildLoginCard(),
                        const SizedBox(height: 16),
                        const Text(
                          "© CivicFix 2026",
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: const Column(
        children: [
          Icon(Icons.location_city, color: Colors.white, size: 52),
          SizedBox(height: 10),
          Text(
            "CivicFix",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Report issues • Track status • Get it fixed",
            style: TextStyle(fontSize: 13, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: -0.12, end: 0);
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 25,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Login",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Welcome back 👋 Please sign in to continue.",
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 18),
          _inputField(
            controller: _usernameController,
            label: "Username",
            hint: "Enter your username",
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          _inputField(
            controller: _passwordController,
            label: "Password",
            hint: "Enter your password",
            icon: Icons.lock_outline,
            obscureText: !_showPassword,
            suffix: IconButton(
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white70,
              ),
            ),
          ),
          if (_adminModeEnabled) ...[
            const SizedBox(height: 14),
            _inputField(
              controller: _adminCodeController,
              label: "Admin Secret Code",
              hint: "Enter secret code",
              icon: Icons.admin_panel_settings_rounded,
              obscureText: true,
            ),
          ],
          const SizedBox(height: 12),
          if (_error != null) _buildErrorWidget(),
          const SizedBox(height: 14),
          _buildLoginButton(),
          const SizedBox(height: 12),
          _buildFooterButtons(),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.35)),
      ),
      child: Text(
        _error!,
        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF38BDF8),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _loading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset("assets/lottie/loading.json", width: 36),
                  const SizedBox(width: 10),
                  const Text(
                    "Logging in...",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ],
              )
            : const Text(
                "Login",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }

  Widget _buildFooterButtons() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.push(
                context,
                _smoothRoute(const ForgotPasswordScreen()),
              ),
              child: const Text(
                "Forgot password?",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.push(context, _smoothRoute(const RegisterScreen())),
              child: const Text(
                "Create account",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () =>
              setState(() => _adminModeEnabled = !_adminModeEnabled),
          child: Text(
            _adminModeEnabled ? "Login as User" : "Login as Admin",
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: Icon(icon, color: Colors.white70),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF38BDF8),
                width: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Background and Particle Painter classes follow...
class _PremiumGradientBackground extends StatelessWidget {
  const _PremiumGradientBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0B1220)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _FloatingBlobs extends StatelessWidget {
  final AnimationController controller;
  const _FloatingBlobs({required this.controller});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        return Stack(
          children: [
            Positioned(
              top: 80 + sin(t * 2 * pi) * 14,
              left: -40 + cos(t * 2 * pi) * 10,
              child: _Blob(
                size: 220,
                color: const Color(0xFF38BDF8).withOpacity(0.18),
              ),
            ),
            Positioned(
              bottom: 80 + cos(t * 2 * pi) * 14,
              right: -60 + sin(t * 2 * pi) * 12,
              child: _Blob(
                size: 260,
                color: const Color(0xFF22C55E).withOpacity(0.12),
              ),
            ),
            Positioned(
              top: 320 + sin(t * 2 * pi) * 18,
              right: 40 + cos(t * 2 * pi) * 10,
              child: _Blob(
                size: 160,
                color: const Color(0xFFF59E0B).withOpacity(0.10),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 60,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticlesLayer extends StatelessWidget {
  final AnimationController controller;
  const _ParticlesLayer({required this.controller});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _ParticlesPainter(progress: controller.value),
        size: MediaQuery.of(context).size,
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final double progress;
  _ParticlesPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rand = Random(7);
    for (int i = 0; i < 32; i++) {
      final x = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final y = baseY + sin((progress * 2 * pi) + (i * 0.25)) * 10;
      paint.color = Colors.white.withOpacity(0.05 + rand.nextDouble() * 0.08);
      canvas.drawCircle(Offset(x, y), 1.2 + rand.nextDouble() * 2.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BouncyScrollBehavior extends MaterialScrollBehavior {
  const _BouncyScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

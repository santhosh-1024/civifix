import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _error;

  bool _isValidEmail(String email) {
    final e = email.trim();
    return RegExp(r"^[\w\.\-]+@([\w\-]+\.)+[\w]{2,}$").hasMatch(e);
  }

  Future<bool> _isUsernameTaken(String username) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: username)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      print("Error checking username: $e");
      return false; // Fail safe
    }
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ✅ FIX: Convert to lowercase to ensure case-insensitive matching
      final username = _usernameController.text.trim().toLowerCase();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      // ✅ Validations
      if (username.isEmpty) {
        setState(() => _error = "Username is not entered");
        return;
      }

      if (email.isEmpty) {
        setState(() => _error = "Email is not entered");
        return;
      }

      if (!_isValidEmail(email)) {
        setState(() => _error = "Create a valid email");
        return;
      }

      if (password.isEmpty) {
        setState(() => _error = "Password is not entered");
        return;
      }

      if (confirmPassword.isEmpty) {
        setState(() => _error = "Confirm password is not entered");
        return;
      }

      if (password != confirmPassword) {
        setState(() => _error = "Passwords do not match");
        return;
      }

      // ✅ Check username unique
      final taken = await _isUsernameTaken(username);
      if (taken) {
        setState(() => _error = "Username already exists. Try another one.");
        return;
      }

      // ✅ Create Firebase Auth account
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        setState(() => _error = "Registration failed");
        return;
      }

      // ✅ REPLACED: Save extended user details in Firestore
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid) // ✅ UID AS DOCUMENT ID
          .set({
        "uid": user.uid,
        "email": email,
        "username": username, // Saved as lowercase
        "role": "citizen",
        "points": 0,
        "badge": "🥉 Bronze Reporter",
        "createdAt": FieldValue.serverTimestamp(),
      });

      // ✅ Send verification email
      await user.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account created ✅ Verification mail sent 📩"),
        ),
      );

      // ✅ Go back to Login screen
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      setState(() {
        if (e.code == "email-already-in-use") {
          _error = "Email already in use. Try login instead.";
        } else if (e.code == "invalid-email") {
          _error = "Create a valid email";
        } else if (e.code == "weak-password") {
          _error = "Password is too weak (min 6 characters)";
        } else {
          _error = e.message ?? "Registration failed";
        }
      });
    } catch (e) {
      print("General Register Error: $e");
      setState(() {
        _error = "Something went wrong. Check console.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0B1220)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  // Logo / Title
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.person_add_alt_1,
                          color: Colors.white,
                          size: 52,
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Join CivicFix and start reporting issues",
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Register Card
                  Container(
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
                          "Register",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Create your account to continue.",
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 18),

                        // ✅ Username
                        _inputField(
                          controller: _usernameController,
                          label: "Username",
                          hint: "Enter username",
                          icon: Icons.person_outline,
                        ),

                        const SizedBox(height: 14),

                        // Email
                        _inputField(
                          controller: _emailController,
                          label: "Email",
                          hint: "example@gmail.com",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 14),

                        // Password
                        _inputField(
                          controller: _passwordController,
                          label: "Password",
                          hint: "Enter your password",
                          icon: Icons.lock_outline,
                          obscureText: !_showPassword,
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Confirm Password
                        _inputField(
                          controller: _confirmPasswordController,
                          label: "Confirm Password",
                          hint: "Re-enter your password",
                          icon: Icons.lock_outline,
                          obscureText: !_showConfirmPassword,
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _showConfirmPassword = !_showConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _showConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Error message
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 14),

                        // Register Button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text(
                                    "Create Account",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Back to Login
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Already have an account? Login",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
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
          keyboardType: keyboardType,
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
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
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

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
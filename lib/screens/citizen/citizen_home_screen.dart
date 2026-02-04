import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // ❌ Removed as requested
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
// ✅ A. Add Provider imports
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

import '../auth/login_screen.dart';
import 'create_complaint_screen.dart';
import 'my_complaints_screen.dart';
import 'complaint_details_screen.dart';

class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bg;

  @override
  void initState() {
    super.initState();
    _bg = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bg.dispose();
    super.dispose();
  }

  // ✅ LOGOUT
  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          "Logout?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "Are you sure you want to logout?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Logout",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // ✅ USE AUTH PROVIDER
    await context.read<AppAuthProvider>().logout();
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

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains("fixed")) return const Color(0xFF22C55E);
    if (s.contains("progress")) return const Color(0xFF60A5FA);
    return const Color(0xFFF59E0B);
  }

  int _statusStep(String status) {
    final s = status.toLowerCase();
    if (s.contains("fixed")) return 3;
    if (s.contains("progress")) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ REPLACED LOGIC: Using AuthProvider
    final auth = context.watch<AppAuthProvider>();

    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = auth.firebaseUser;

    if (user == null) {
      return const LoginScreen();
    }

    final complaintsQuery = FirebaseFirestore.instance
        .collection("complaints")
        .where("userId", isEqualTo: user.uid)
        .orderBy("createdAt", descending: true);

    return Scaffold(
      body: Stack(
        children: [
          const _PremiumCityGradient(),

          // 🏙️ Animated City Skyline Wave
          _CitySkylineWave(controller: _bg),

          // ✅ Floating blobs
          _FloatingBlobs(controller: _bg),

          // ✅ Particles
          _PremiumParticlesLayer(controller: _bg),

          // ✅ Smart City icons
          _SmartCityIconsLayer(controller: _bg),

          // UI
          SafeArea(
            child: Column(
              children: [
                // TOP BAR
                Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: const Icon(
                              Icons.location_city,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Citizen Dashboard",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _logout(context),
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                            ),
                            tooltip: "Logout",
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 450.ms)
                    .slideY(begin: -0.15, end: 0),

                Expanded(
                  child: ScrollConfiguration(
                    behavior: const _BouncyScrollBehavior(),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 950),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // WELCOME HERO CARD
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection("users")
                                  .doc(user.uid)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                String username = "Citizen";

                                // ✅ NEW: points + badge
                                int points = 0;
                                String badge = "🥉 Bronze Reporter";

                                if (snapshot.hasData && snapshot.data!.exists) {
                                  final data =
                                      snapshot.data!.data()
                                          as Map<String, dynamic>;

                                  username = (data["username"] ?? "Citizen")
                                      .toString()
                                      .trim();
                                  if (username.isEmpty) username = "Citizen";

                                  final p = data["points"];
                                  if (p is int) points = p;
                                  if (p is num) points = p.toInt();

                                  badge = (data["badge"] ?? badge).toString();
                                  if (badge.trim().isEmpty) {
                                    badge = "🥉 Bronze Reporter";
                                  }
                                }

                                return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.14),
                                        ),
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(
                                              0xFF38BDF8,
                                            ).withOpacity(0.22),
                                            Colors.white.withOpacity(0.06),
                                            Colors.black.withOpacity(0.22),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.45,
                                            ),
                                            blurRadius: 30,
                                            offset: const Offset(0, 16),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                height: 52,
                                                width: 52,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF38BDF8,
                                                    ).withOpacity(0.55),
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  color: Colors.white,
                                                  size: 26,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      "Welcome 👋",
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      username,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    const Text(
                                                      "Report issues • Track status • Get it fixed",
                                                      style: TextStyle(
                                                        color: Colors.white60,
                                                        fontSize: 12.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.07),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.12),
                                                  ),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(
                                                      Icons.verified_rounded,
                                                      color: Color(0xFF22C55E),
                                                      size: 18,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      "Active",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 14),

                                          // ✅ NEW: POINTS + BADGE ROW
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.06),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.12),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.star_rounded,
                                                        color: Color(
                                                          0xFFF59E0B,
                                                        ),
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          "Points: $points",
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                fontSize: 12.8,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.06),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.12),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .emoji_events_rounded,
                                                        color: Color(
                                                          0xFF38BDF8,
                                                        ),
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          badge,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                fontSize: 12.8,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 500.ms)
                                    .slideX(begin: -0.06, end: 0)
                                    .scale(
                                      begin: const Offset(0.98, 0.98),
                                      end: const Offset(1, 1),
                                    )
                                    .shimmer(duration: 1400.ms, delay: 700.ms);
                              },
                            ),

                            const SizedBox(height: 18),

                            const Text(
                              "Quick Actions",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ).animate().fadeIn(duration: 350.ms),

                            const SizedBox(height: 12),

                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 720;

                                return Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  children: [
                                    SizedBox(
                                      width: isWide
                                          ? (constraints.maxWidth - 28) / 3
                                          : constraints.maxWidth,
                                      child:
                                          _PremiumActionTile(
                                                icon: Icons
                                                    .add_circle_outline_rounded,
                                                title: "Create",
                                                subtitle: "New complaint",
                                                color: const Color(0xFF38BDF8),
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  Navigator.push(
                                                    context,
                                                    _smoothRoute(
                                                      const CreateComplaintScreen(),
                                                    ),
                                                  );
                                                },
                                              )
                                              .animate()
                                              .fadeIn(
                                                duration: 350.ms,
                                                delay: 80.ms,
                                              )
                                              .slideY(begin: 0.10, end: 0),
                                    ),
                                    SizedBox(
                                      width: isWide
                                          ? (constraints.maxWidth - 28) / 3
                                          : constraints.maxWidth,
                                      child:
                                          _PremiumActionTile(
                                                icon: Icons.list_alt_rounded,
                                                title: "My Reports",
                                                subtitle: "Track status",
                                                color: const Color(0xFF60A5FA),
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  Navigator.push(
                                                    context,
                                                    _smoothRoute(
                                                      const MyComplaintsScreen(),
                                                    ),
                                                  );
                                                },
                                              )
                                              .animate()
                                              .fadeIn(
                                                duration: 350.ms,
                                                delay: 140.ms,
                                              )
                                              .slideY(begin: 0.10, end: 0),
                                    ),
                                    SizedBox(
                                      width: isWide
                                          ? (constraints.maxWidth - 28) / 3
                                          : constraints.maxWidth,
                                      child:
                                          _PremiumActionTile(
                                                icon: Icons.map_outlined,
                                                title: "Nearby",
                                                subtitle: "Coming soon",
                                                color: const Color(0xFF22C55E),
                                                onTap: () {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        "Nearby Issues coming soon 🚀",
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                              .animate()
                                              .fadeIn(
                                                duration: 350.ms,
                                                delay: 200.ms,
                                              )
                                              .slideY(begin: 0.10, end: 0),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            const Text(
                              "Your Complaint Summary",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ).animate().fadeIn(duration: 350.ms),

                            const SizedBox(height: 12),

                            StreamBuilder<QuerySnapshot>(
                              stream: complaintsQuery.snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Lottie.asset(
                                        "assets/lottie/loading.json",
                                        width: 90,
                                      ),
                                    ),
                                  );
                                }

                                final docs = snapshot.data?.docs ?? [];

                                int total = docs.length;
                                int pending = 0;
                                int progress = 0;
                                int fixed = 0;

                                for (final d in docs) {
                                  final data = d.data() as Map<String, dynamic>;
                                  final status = (data["status"] ?? "Pending")
                                      .toString();

                                  final s = status.toLowerCase();
                                  if (s.contains("fixed") ||
                                      s.contains("verified")) {
                                    fixed++;
                                  } else if (s.contains("progress")) {
                                    progress++;
                                  } else {
                                    pending++;
                                  }
                                }

                                return LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isWide =
                                            constraints.maxWidth > 600;

                                        return GridView.count(
                                          crossAxisCount: isWide ? 4 : 2,
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          childAspectRatio: isWide ? 2.7 : 2.3,
                                          children: [
                                            _AnimatedStatCard(
                                              title: "Total",
                                              value: total,
                                              icon: Icons.list_alt_rounded,
                                              color: const Color(0xFF38BDF8),
                                            ),
                                            _AnimatedStatCard(
                                              title: "Pending",
                                              value: pending,
                                              icon: Icons
                                                  .hourglass_bottom_rounded,
                                              color: const Color(0xFFF59E0B),
                                            ),
                                            _AnimatedStatCard(
                                              title: "In Progress",
                                              value: progress,
                                              icon: Icons.build_circle_outlined,
                                              color: const Color(0xFF60A5FA),
                                            ),
                                            _AnimatedStatCard(
                                              title: "Fixed",
                                              value: fixed,
                                              icon: Icons.verified_rounded,
                                              color: const Color(0xFF22C55E),
                                            ),
                                          ],
                                        );
                                      },
                                    )
                                    .animate()
                                    .fadeIn(duration: 350.ms)
                                    .slideY(begin: 0.10, end: 0);
                              },
                            ),

                            const SizedBox(height: 18),

                            const Text(
                              "Recent Complaints",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ).animate().fadeIn(duration: 350.ms),

                            const SizedBox(height: 12),

                            StreamBuilder<QuerySnapshot>(
                              stream: complaintsQuery.limit(5).snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Center(
                                      child: Lottie.asset(
                                        "assets/lottie/loading.json",
                                        width: 90,
                                      ),
                                    ),
                                  );
                                }

                                final docs = snapshot.data?.docs ?? [];

                                if (docs.isEmpty) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.12),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Lottie.asset(
                                          "assets/lottie/empty.json",
                                          width: 150,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          "No complaints yet",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          "Create a complaint to see it here.",
                                          style: TextStyle(
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).animate().fadeIn(duration: 350.ms);
                                }

                                return Column(
                                  children: docs.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;

                                    final type = (data["type"] ?? "Unknown")
                                        .toString();
                                    final status = (data["status"] ?? "Pending")
                                        .toString();
                                    final address = (data["address"] ?? "")
                                        .toString();
                                    final createdAt = data["createdAt"];

                                    DateTime? dt;
                                    if (createdAt is Timestamp) {
                                      dt = createdAt.toDate();
                                    }

                                    final dateText = dt == null
                                        ? "Just now"
                                        : DateFormat(
                                            "dd MMM • hh:mm a",
                                          ).format(dt);

                                    final color = _statusColor(status);
                                    final step = _statusStep(status);

                                    return _HoverRecentTile(
                                          title: type,
                                          address: address.isEmpty
                                              ? "Address not saved"
                                              : address,
                                          dateText: dateText,
                                          status: status,
                                          color: color,
                                          step: step,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              _smoothRoute(
                                                ComplaintDetailsScreen(
                                                  complaintId: doc.id,
                                                  complaintData: data,
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                        .animate()
                                        .fadeIn(duration: 300.ms)
                                        .slideX(begin: 0.06, end: 0);
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================== CITY SKYLINE WAVE ==================
class _CitySkylineWave extends StatelessWidget {
  final AnimationController controller;
  const _CitySkylineWave({required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _CityPainter(progress: controller.value),
          );
        },
      ),
    );
  }
}

class _CityPainter extends CustomPainter {
  final double progress;
  _CityPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    final baseY = size.height * 0.74;
    final wave = sin(progress * pi * 2) * 12;

    double x = 0;
    final path = Path()..moveTo(0, size.height);

    final rand = Random(42);

    while (x < size.width + 60) {
      final w = 45 + rand.nextDouble() * 50;
      final h = 25 + rand.nextDouble() * 90;

      path.lineTo(x, baseY - h + wave);
      path.lineTo(x + w, baseY - h + wave);
      x += w;
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CityPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ================= SMART CITY ICONS =================
class _SmartCityIconsLayer extends StatelessWidget {
  final AnimationController controller;
  const _SmartCityIconsLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final t = controller.value;
          return Stack(
            children: [
              _floatingIcon(
                icon: Icons.location_on_rounded,
                left: 30,
                top: 140,
                t: t,
                speed: 1.0,
              ),
              _floatingIcon(
                icon: Icons.apartment_rounded,
                right: 40,
                top: 120,
                t: t,
                speed: 1.3,
              ),
              _floatingIcon(
                icon: Icons.build_rounded,
                left: 80,
                bottom: 120,
                t: t,
                speed: 1.15,
              ),
              _floatingIcon(
                icon: Icons.traffic_rounded,
                right: 60,
                bottom: 160,
                t: t,
                speed: 1.05,
              ),
              _floatingIcon(
                icon: Icons.lightbulb_rounded,
                left: 220,
                top: 260,
                t: t,
                speed: 1.25,
              ),
              _floatingIcon(
                icon: Icons.campaign_rounded,
                right: 200,
                top: 320,
                t: t,
                speed: 1.1,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _floatingIcon({
    required IconData icon,
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double t,
    required double speed,
  }) {
    final dy = sin((t * 2 * pi) * speed) * 12;
    final dx = cos((t * 2 * pi) * speed) * 8;

    return Positioned(
      left: left,
      right: right,
      top: top != null ? top + dy : null,
      bottom: bottom != null ? bottom + dy : null,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Icon(icon, size: 22, color: Colors.white.withOpacity(0.20)),
        ),
      ),
    );
  }
}

// ================= BACKGROUND GRADIENT =================
class _PremiumCityGradient extends StatelessWidget {
  const _PremiumCityGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.7, -0.6),
          radius: 1.2,
          colors: [Color(0xFF1E3A8A), Color(0xFF0F172A), Color(0xFF050A12)],
        ),
      ),
    );
  }
}

// ================= PARTICLES =================
class _PremiumParticlesLayer extends StatelessWidget {
  final AnimationController controller;
  const _PremiumParticlesLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return CustomPaint(
            painter: _ParticlesPainter(progress: controller.value),
            size: MediaQuery.of(context).size,
          );
        },
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final double progress;
  _ParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(88);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 60; i++) {
      final x = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;

      final wave = sin((progress * 2 * pi) + (i * 0.35)) * 14;
      final y = baseY + wave;

      final r = 1 + rand.nextDouble() * 2.6;
      paint.color = Colors.white.withOpacity(0.03 + rand.nextDouble() * 0.08);

      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ================= BLOBS =================
class _FloatingBlobs extends StatelessWidget {
  final AnimationController controller;
  const _FloatingBlobs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final t = controller.value;
          return Stack(
            children: [
              Positioned(
                top: 90 + sin(t * 2 * pi) * 18,
                left: -80 + cos(t * 2 * pi) * 18,
                child: _Blob(
                  size: 280,
                  color: const Color(0xFF38BDF8).withOpacity(0.14),
                ),
              ),
              Positioned(
                top: 260 + cos(t * 2 * pi) * 20,
                right: -100 + sin(t * 2 * pi) * 14,
                child: _Blob(
                  size: 320,
                  color: const Color(0xFF22C55E).withOpacity(0.11),
                ),
              ),
              Positioned(
                bottom: 80 + sin(t * 2 * pi) * 18,
                right: 10 + cos(t * 2 * pi) * 12,
                child: _Blob(
                  size: 240,
                  color: const Color(0xFFF59E0B).withOpacity(0.10),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 80,
                spreadRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= QUICK ACTION TILE =================
class _PremiumActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PremiumActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_PremiumActionTile> createState() => _PremiumActionTileState();
}

class _PremiumActionTileState extends State<_PremiumActionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(18),
            transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: _hover
                    ? widget.color.withOpacity(0.75)
                    : Colors.white.withOpacity(0.14),
                width: 1.2,
              ),
              gradient: LinearGradient(
                colors: [
                  widget.color.withOpacity(_hover ? 0.30 : 0.18),
                  Colors.white.withOpacity(0.06),
                  Colors.black.withOpacity(0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_hover ? 0.55 : 0.30),
                  blurRadius: _hover ? 34 : 22,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOut,
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: widget.color.withOpacity(_hover ? 0.40 : 0.22),
                    border: Border.all(
                      color: widget.color.withOpacity(_hover ? 0.85 : 0.45),
                      width: 1.1,
                    ),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: _hover
                        ? widget.color.withOpacity(0.25)
                        : Colors.white.withOpacity(0.06),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= ANIMATED STAT CARD =================
class _AnimatedStatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _AnimatedStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverStatCard(
      title: title,
      icon: icon,
      color: color,
      animatedValue: value,
    );
  }
}

class _HoverStatCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int animatedValue;

  const _HoverStatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.animatedValue,
  });

  @override
  State<_HoverStatCard> createState() => _HoverStatCardState();
}

class _HoverStatCardState extends State<_HoverStatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hover
                  ? widget.color.withOpacity(0.65)
                  : Colors.white.withOpacity(0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_hover ? 0.50 : 0.30),
                blurRadius: _hover ? 28 : 20,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.color.withOpacity(0.45)),
                ),
                child: Icon(widget.icon, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: widget.animatedValue.toDouble(),
                    ),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) {
                      return Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= RECENT TILE + STEPPER =================
class _HoverRecentTile extends StatefulWidget {
  final String title;
  final String address;
  final String dateText;
  final String status;
  final Color color;
  final int step;
  final VoidCallback onTap;

  const _HoverRecentTile({
    required this.title,
    required this.address,
    required this.dateText,
    required this.status,
    required this.color,
    required this.step,
    required this.onTap,
  });

  @override
  State<_HoverRecentTile> createState() => _HoverRecentTileState();
}

class _HoverRecentTileState extends State<_HoverRecentTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _hover
                    ? widget.color.withOpacity(0.14)
                    : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _hover
                      ? widget.color.withOpacity(0.55)
                      : Colors.white.withOpacity(0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_hover ? 0.55 : 0.30),
                    blurRadius: _hover ? 28 : 20,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.color.withOpacity(0.40)),
                    ),
                    child: Icon(
                      Icons.report_problem_rounded,
                      color: widget.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: widget.color.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.color.withOpacity(0.35),
                                ),
                              ),
                              child: Text(
                                widget.status,
                                style: TextStyle(
                                  color: widget.color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.dateText,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _StatusStepper(step: widget.step, color: widget.color),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white54,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final int step;
  final Color color;

  const _StatusStepper({required this.step, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(active: step >= 1),
        _line(active: step >= 2),
        _dot(active: step >= 2),
        _line(active: step >= 3),
        _dot(active: step >= 3),
      ],
    );
  }

  Widget _dot({required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 10,
      width: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : Colors.white.withOpacity(0.18),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withOpacity(0.55),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
    );
  }

  Widget _line({required bool active}) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: active
              ? color.withOpacity(0.85)
              : Colors.white.withOpacity(0.12),
        ),
      ),
    );
  }
}

// ================= SCROLL BEHAVIOR =================
class _BouncyScrollBehavior extends MaterialScrollBehavior {
  const _BouncyScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
 
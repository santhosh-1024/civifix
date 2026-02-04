import 'package:confetti/confetti.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../auth/login_screen.dart';
import '../citizen/complaint_details_screen.dart';
import '../../services/points_service.dart'; // ✅ NEW

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late ConfettiController _confettiController;

  String selectedFilter = "All";
  String searchText = "";

  // ✅ Sort toggle
  bool sortByMostUpvoted = false;

  final List<String> filters = ["All", "Pending", "In Progress", "Fixed"];

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains("fixed")) return const Color(0xFF22C55E);
    if (s.contains("progress")) return const Color(0xFF60A5FA);
    return const Color(0xFFF59E0B);
  }

  bool _isOverdue(Map<String, dynamic> data) {
    final status = (data["status"] ?? "Pending").toString().toLowerCase();
    if (status.contains("fixed")) return false;

    final createdAt = data["createdAt"];
    if (createdAt is! Timestamp) return false;

    final created = createdAt.toDate();
    final diffDays = DateTime.now().difference(created).inDays;
    return diffDays > 7;
  }

  double _medianResolutionDays(List<QueryDocumentSnapshot> docs) {
    final List<double> days = [];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final status = (data["status"] ?? "Pending").toString().toLowerCase();
      if (!status.contains("fixed")) continue;

      final createdAt = data["createdAt"];
      final fixedAt = data["fixedAt"];

      if (createdAt is Timestamp && fixedAt is Timestamp) {
        final created = createdAt.toDate();
        final fixed = fixedAt.toDate();
        final diff = fixed.difference(created).inMinutes / (60 * 24);
        if (diff >= 0) days.add(diff);
      }
    }

    if (days.isEmpty) return 0;

    days.sort();
    final mid = days.length ~/ 2;

    if (days.length.isOdd) {
      return days[mid];
    } else {
      return (days[mid - 1] + days[mid]) / 2.0;
    }
  }

  // ✅ LOGOUT CONFIRMATION
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          "Logout?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "Are you sure you want to logout from Admin Dashboard?",
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

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _updateStatus({
    required String complaintId,
    required String newStatus,
  }) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection("complaints")
          .doc(complaintId);

      final Map<String, dynamic> dataToUpdate = {
        "status": newStatus,
        "updatedAt": FieldValue.serverTimestamp(),
      };

      // ✅ Save timeline timestamps (Premium)
      if (newStatus.toLowerCase() == "assigned") {
        dataToUpdate["assignedAt"] = FieldValue.serverTimestamp();
      }

      if (newStatus.toLowerCase().contains("progress")) {
        dataToUpdate["inProgressAt"] = FieldValue.serverTimestamp();
      }

      // ✅ Save fixedAt when status becomes Fixed
      if (newStatus.toLowerCase().contains("fixed")) {
        dataToUpdate["fixedAt"] = FieldValue.serverTimestamp();
      }

      if (newStatus.toLowerCase().contains("verified")) {
        dataToUpdate["verifiedAt"] = FieldValue.serverTimestamp();
      }

      await ref.update(dataToUpdate);

      // ===================== ✅ POINTS REWARD SYSTEM (NEW) =====================
      final snap = await ref.get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final ownerId = (data["userId"] ?? "").toString();

        if (ownerId.isNotEmpty) {
          // ✅ FIXED reward (+10) only once
          if (newStatus.toLowerCase().contains("fixed")) {
            final bool alreadyRewarded =
                (data["fixedRewardGiven"] ?? false) == true;

            if (!alreadyRewarded) {
              await ref.update({"fixedRewardGiven": true});
              await PointsService.addPoints(userId: ownerId, pointsToAdd: 10);
            }
          }

          // ✅ VERIFIED reward (+5) only once
          if (newStatus.toLowerCase().contains("verified")) {
            final bool alreadyRewarded =
                (data["verifiedRewardGiven"] ?? false) == true;

            if (!alreadyRewarded) {
              await ref.update({"verifiedRewardGiven": true});
              await PointsService.addPoints(userId: ownerId, pointsToAdd: 5);
            }
          }
        }
      }
      // ===================== ✅ END POINTS SYSTEM =====================

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Status updated to $newStatus ✅")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Update failed: $e")));
    }
  }

  Future<void> _statusDialog(String complaintId, String currentStatus) async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          "Change Status",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusOption("Pending", currentStatus),
            _statusOption("Assigned", currentStatus),
            _statusOption("In Progress", currentStatus),
            _statusOption("Fixed", currentStatus),
            _statusOption("Verified", currentStatus),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );

    if (newStatus == null) return;
    await _updateStatus(complaintId: complaintId, newStatus: newStatus);
  }

  Widget _statusOption(String status, String currentStatus) {
    final isSelected =
        currentStatus.toLowerCase() == status.toLowerCase().trim();

    final c = _statusColor(status);

    return ListTile(
      onTap: () => Navigator.pop(context, status),
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? c : Colors.white54,
      ),
      title: Text(
        status,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withOpacity(0.40)),
        ),
        child: Text(
          status,
          style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }

  // ================== MINI STAT CARD ==================
  Widget _miniStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.45)),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================== NEW PREMIUM WEEKLY TREND UI ==================
  Widget _weeklyChart(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<DateTime> days = List.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );

    final List<int> counts = List.filled(7, 0);

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = data["createdAt"];
      if (createdAt is! Timestamp) continue;

      final dt = createdAt.toDate();
      final createdDay = DateTime(dt.year, dt.month, dt.day);

      for (int i = 0; i < 7; i++) {
        if (createdDay == days[i]) {
          counts[i]++;
          break;
        }
      }
    }

    final totalWeek = counts.fold<int>(0, (a, b) => a + b);
    final maxVal = counts.reduce((a, b) => a > b ? a : b);
    final maxSafe = maxVal == 0 ? 1 : maxVal;

    final labels = days.map((d) => DateFormat("E").format(d)).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "7-Day Trend",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withOpacity(0.35),
                  ),
                ),
                child: Text(
                  "$totalWeek total",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: List.generate(7, (i) {
              final v = counts[i];
              final ratio = v / maxSafe;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 10 + (ratio * 18),
                      width: 10 + (ratio * 18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: v == 0
                            ? Colors.white.withOpacity(0.10)
                            : const Color(0xFF38BDF8).withOpacity(0.55),
                        border: Border.all(
                          color: v == 0
                              ? Colors.white.withOpacity(0.10)
                              : const Color(0xFF38BDF8).withOpacity(0.75),
                        ),
                        boxShadow: v == 0
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8)
                                      .withOpacity(0.25),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      v.toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection("complaints")
        .orderBy("createdAt", descending: true);

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
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Admin Dashboard",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: sortByMostUpvoted
                          ? "Sorting: Most Upvoted"
                          : "Sorting: Latest",
                      onPressed: () {
                        setState(() {
                          sortByMostUpvoted = !sortByMostUpvoted;
                        });
                      },
                      icon: Icon(
                        sortByMostUpvoted
                            ? Icons.local_fire_department_rounded
                            : Icons.schedule_rounded,
                        color: sortByMostUpvoted
                            ? const Color(0xFFF59E0B)
                            : Colors.white70,
                      ),
                    ),
                    IconButton(
                      tooltip: "Logout",
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.30),
                          blurRadius: 18,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Search by type, status, address...",
                        hintStyle: TextStyle(color: Colors.white54),
                        prefixIcon: Icon(Icons.search, color: Colors.white54),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchText = value.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final f = filters[index];
                    final isSelected = selectedFilter == f;

                    return GestureDetector(
                      onTap: () => setState(() => selectedFilter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isSelected
                                ? _statusColor(f).withOpacity(0.90)
                                : Colors.white.withOpacity(0.14),
                          ),
                          color: isSelected
                              ? _statusColor(f).withOpacity(0.18)
                              : Colors.white.withOpacity(0.08),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: query.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Error: ${snapshot.error}",
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF38BDF8),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    int total = docs.length;
                    int pending = 0;
                    int progress = 0;
                    int fixed = 0;
                    int overdueCount = 0;

                    for (final d in docs) {
                      final data = d.data() as Map<String, dynamic>;
                      final status = (data["status"] ?? "Pending").toString();
                      final s = status.toLowerCase();

                      if (s.contains("fixed")) {
                        fixed++;
                      } else if (s.contains("progress")) {
                        progress++;
                      } else {
                        pending++;
                      }

                      if (_isOverdue(data)) overdueCount++;
                    }

                    final medianDays = _medianResolutionDays(docs);

                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      final status = (data["status"] ?? "Pending").toString();
                      final type = (data["type"] ?? "Unknown").toString();
                      final desc = (data["description"] ?? "").toString();
                      final address = (data["address"] ?? "").toString();

                      final statusMatch = selectedFilter == "All"
                          ? true
                          : status.toLowerCase().contains(
                                selectedFilter.toLowerCase(),
                              );

                      final searchMatch = searchText.isEmpty
                          ? true
                          : (type.toLowerCase().contains(searchText) ||
                              desc.toLowerCase().contains(searchText) ||
                              status.toLowerCase().contains(searchText) ||
                              address.toLowerCase().contains(searchText));

                      return statusMatch && searchMatch;
                    }).toList();

                    filteredDocs.sort((a, b) {
                      final ad = a.data() as Map<String, dynamic>;
                      final bd = b.data() as Map<String, dynamic>;

                      if (sortByMostUpvoted) {
                        final au = (ad["upvotes"] ?? 0) as num;
                        final bu = (bd["upvotes"] ?? 0) as num;
                        return bu.compareTo(au);
                      }

                      final at = ad["createdAt"];
                      final bt = bd["createdAt"];
                      if (at is Timestamp && bt is Timestamp) {
                        return bt.compareTo(at);
                      }
                      return 0;
                    });

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 700;
                            final cardW = isWide
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth;

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: cardW,
                                  child: _miniStatCard(
                                    title: "Total Complaints",
                                    value: total.toString(),
                                    icon: Icons.list_alt_rounded,
                                    color: const Color(0xFF38BDF8),
                                  ),
                                ),
                                SizedBox(
                                  width: cardW,
                                  child: _miniStatCard(
                                    title: "Pending",
                                    value: pending.toString(),
                                    icon: Icons.hourglass_bottom_rounded,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                                SizedBox(
                                  width: cardW,
                                  child: _miniStatCard(
                                    title: "In Progress",
                                    value: progress.toString(),
                                    icon: Icons.build_circle_outlined,
                                    color: const Color(0xFF60A5FA),
                                  ),
                                ),
                                SizedBox(
                                  width: cardW,
                                  child: _miniStatCard(
                                    title: "Fixed",
                                    value: fixed.toString(),
                                    icon: Icons.verified_rounded,
                                    color: const Color(0xFF22C55E),
                                  ),
                                ),
                                SizedBox(
                                  width: cardW,
                                  child: _miniStatCard(
                                    title: "Overdue (>7 days)",
                                    value: overdueCount.toString(),
                                    icon: Icons.warning_rounded,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                SizedBox(
                                  width: cardW,
                                  child: _miniStatCard(
                                    title: "Median Resolution Time",
                                    value: medianDays == 0
                                        ? "No data"
                                        : "${medianDays.toStringAsFixed(1)} days",
                                    icon: Icons.timer_rounded,
                                    color: const Color(0xFF38BDF8),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _weeklyChart(docs),
                        const SizedBox(height: 14),
                        if (filteredDocs.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: Text(
                                "No complaints found",
                                style: TextStyle(color: Colors.white60),
                              ),
                            ),
                          ),
                        ...filteredDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;

                          final type = (data["type"] ?? "Unknown").toString();
                          final status =
                              (data["status"] ?? "Pending").toString();
                          final address =
                              (data["address"] ?? "No address").toString();

                          final upvotes = (data["upvotes"] ?? 0);

                          DateTime? createdAt;
                          final ts = data["createdAt"];
                          if (ts is Timestamp) createdAt = ts.toDate();

                          final dateText = createdAt == null
                              ? "Just now"
                              : DateFormat("dd MMM • hh:mm a").format(createdAt);

                          final c = _statusColor(status);

                          final overdue = _isOverdue(data);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: overdue
                                      ? Colors.redAccent.withOpacity(0.10)
                                      : Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: overdue
                                        ? Colors.redAccent.withOpacity(0.75)
                                        : Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 54,
                                      width: 54,
                                      decoration: BoxDecoration(
                                        color: overdue
                                            ? Colors.redAccent.withOpacity(0.20)
                                            : c.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: overdue
                                              ? Colors.redAccent.withOpacity(
                                                  0.55,
                                                )
                                              : c.withOpacity(0.40),
                                        ),
                                      ),
                                      child: Icon(
                                        overdue
                                            ? Icons.warning_rounded
                                            : Icons.report_problem_rounded,
                                        color: overdue ? Colors.redAccent : c,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  type,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 14.5,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.06),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.12),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.thumb_up_alt_rounded,
                                                      size: 14,
                                                      color: Color(0xFFF59E0B),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      upvotes.toString(),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 11.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: c.withOpacity(0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                  border: Border.all(
                                                    color: c.withOpacity(0.40),
                                                  ),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    color: c,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                dateText,
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              if (overdue)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent
                                                        .withOpacity(0.18),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                    border: Border.all(
                                                      color: Colors.redAccent
                                                          .withOpacity(0.55),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    "Overdue >7 days",
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      tooltip: "View Details",
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ComplaintDetailsScreen(
                                              complaintId: doc.id,
                                              complaintData: data,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.open_in_new_rounded,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: "Change Status",
                                      onPressed: () =>
                                          _statusDialog(doc.id, status),
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        color: Color(0xFF38BDF8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

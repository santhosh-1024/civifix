import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final String complaintId;
  final Map<String, dynamic> complaintData;

  const ComplaintDetailsScreen({
    super.key,
    required this.complaintId,
    required this.complaintData,
  });

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  bool _loading = false;

  late String _type;
  late String _desc;
  late String _status;
  late String _address;
  late String _imageUrl;

  double? _lat;
  double? _lng;

  DateTime? _createdAt;

  // ✅ Upvote UI
  bool _upvoting = false;
  int _upvotes = 0;
  bool _alreadyUpvoted = false;

  // ✅ Verify UI
  bool _verifying = false;

  @override
  void initState() {
    super.initState();

    final data = widget.complaintData;

    _type = (data["type"] ?? "Unknown").toString();
    _desc = (data["description"] ?? "").toString();
    _status = (data["status"] ?? "Pending").toString();
    _address = (data["address"] ?? "No address").toString();
    _imageUrl = (data["imageUrl"] ?? "").toString();

    final lat = data["lat"];
    final lng = data["lng"];
    if (lat is num) _lat = lat.toDouble();
    if (lng is num) _lng = lng.toDouble();

    final ts = data["createdAt"];
    if (ts is Timestamp) _createdAt = ts.toDate();

    // ✅ upvote values (fallback safe)
    _upvotes = (data["upvotes"] ?? 0) is int ? (data["upvotes"] ?? 0) : 0;

    final user = FirebaseAuth.instance.currentUser;
    final List upvotedBy = (data["upvotedBy"] ?? []);
    _alreadyUpvoted = user != null && upvotedBy.contains(user.uid);
  }

  // ====================== POINTS + BADGE HELPERS ======================
  String _badgeFromPoints(int points) {
    if (points >= 150) return "🥇 Gold Civic Hero";
    if (points >= 50) return "🥈 Silver Helper";
    return "🥉 Bronze Reporter";
  }

  Future<void> _addPointsToUser({
    required String uid,
    required int addPoints,
  }) async {
    final userRef = FirebaseFirestore.instance.collection("users").doc(uid);

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(userRef);

      int current = 0;
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final p = data["points"];
        if (p is int) current = p;
        if (p is num) current = p.toInt();
      }

      final newPoints = current + addPoints;
      final newBadge = _badgeFromPoints(newPoints);

      if (snap.exists) {
        txn.update(userRef, {"points": newPoints, "badge": newBadge});
      } else {
        txn.set(userRef, {"points": newPoints, "badge": newBadge});
      }
    });
  }

  // ====================== UPVOTE ======================
  Future<void> _upvoteComplaint() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to upvote ❌")),
      );
      return;
    }

    if (_alreadyUpvoted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You already upvoted this complaint ✅")),
      );
      return;
    }

    try {
      setState(() => _upvoting = true);

      final ref = FirebaseFirestore.instance
          .collection("complaints")
          .doc(widget.complaintId);

      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>;
        final List upvotedBy = (data["upvotedBy"] ?? []);
        final int currentUpvotes = (data["upvotes"] ?? 0) is int
            ? (data["upvotes"] ?? 0)
            : 0;

        if (upvotedBy.contains(user.uid)) {
          throw Exception("Already upvoted");
        }

        txn.update(ref, {
          "upvotes": currentUpvotes + 1,
          "upvotedBy": FieldValue.arrayUnion([user.uid]),
        });
      });

      // ✅ Add points for upvoting duplicates (+2)
      await _addPointsToUser(uid: user.uid, addPoints: 2);

      if (!mounted) return;

      setState(() {
        _upvotes += 1;
        _alreadyUpvoted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upvoted successfully 🔥 (+2 points)")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upvote failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _upvoting = false);
    }
  }

  // ====================== VERIFY FIXED (CITIZEN) ======================
  Future<void> _verifyFixedComplaint() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login ❌")),
      );
      return;
    }

    final s = _status.toLowerCase();
    if (!s.contains("fixed")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Only Fixed complaints can be verified ✅")),
      );
      return;
    }

    try {
      setState(() => _verifying = true);

      final ref = FirebaseFirestore.instance
          .collection("complaints")
          .doc(widget.complaintId);

      await ref.update({
        "status": "Verified",
        "verifiedAt": FieldValue.serverTimestamp(),
        "verifiedBy": user.uid,
      });

      // ✅ Add points for verifying fixed (+5)
      await _addPointsToUser(uid: user.uid, addPoints: 5);

      if (!mounted) return;

      setState(() {
        _status = "Verified";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verified successfully ✅ (+5 points)")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verify failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  // ====================== OPEN GOOGLE MAPS ======================
  Future<void> _openInGoogleMaps() async {
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No location available ❌")),
      );
      return;
    }

    final url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$_lat,$_lng",
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open Google Maps ❌")),
      );
    }
  }

  // ====================== UI HELPERS ======================
  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains("verified")) return const Color(0xFF22C55E);
    if (s.contains("fixed")) return const Color(0xFF22C55E);
    if (s.contains("progress")) return const Color(0xFF60A5FA);
    return const Color(0xFFF59E0B);
  }

  int _statusStep(String status) {
    final s = status.toLowerCase();
    if (s.contains("verified")) return 3;
    if (s.contains("fixed")) return 3;
    if (s.contains("progress")) return 2;
    return 1;
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 25,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _title(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15.5,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _sub(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 12.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ====================== PREMIUM TIMELINE / STEP TRACKER ======================
  int _timelineStep(String status) {
    final s = status.toLowerCase();
    if (s.contains("verified")) return 5;
    if (s.contains("fixed")) return 4;
    if (s.contains("progress")) return 3;
    if (s.contains("assigned")) return 2;
    return 1;
  }

  Widget _complaintTimeline() {
    final step = _timelineStep(_status);

    Widget dot({
      required bool active,
      required bool done,
      required IconData icon,
      required String label,
    }) {
      final Color activeColor = const Color(0xFF38BDF8);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: done
                  ? activeColor.withOpacity(0.22)
                  : active
                      ? activeColor.withOpacity(0.18)
                      : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: done
                    ? activeColor.withOpacity(0.65)
                    : active
                        ? activeColor.withOpacity(0.45)
                        : Colors.white.withOpacity(0.12),
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: done
                  ? activeColor
                  : active
                      ? activeColor
                      : Colors.white38,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: (done || active) ? Colors.white : Colors.white54,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }

    Widget line(bool active) {
      return Expanded(
        child: Container(
          height: 2.4,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF38BDF8).withOpacity(0.65)
                : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );
    }

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _title("Complaint Timeline"),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Text(
                  "Step $step / 5",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              dot(
                active: step == 1,
                done: step > 1,
                icon: Icons.check_circle_rounded,
                label: "Created",
              ),
              line(step > 1),
              dot(
                active: step == 2,
                done: step > 2,
                icon: Icons.assignment_turned_in_rounded,
                label: "Assigned",
              ),
              line(step > 2),
              dot(
                active: step == 3,
                done: step > 3,
                icon: Icons.build_circle_rounded,
                label: "In Progress",
              ),
              line(step > 3),
              dot(
                active: step == 4,
                done: step > 4,
                icon: Icons.verified_rounded,
                label: "Fixed",
              ),
              line(step > 4),
              dot(
                active: step == 5,
                done: step > 5,
                icon: Icons.verified_user_rounded,
                label: "Verified",
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Timeline updates automatically based on complaint status.",
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12.2,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
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

  // ====================== FULLSCREEN IMAGE ======================
  void _openImageFullscreen(String url) {
    if (url.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: InteractiveViewer(
              minScale: 0.7,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(url),
              ),
            ),
          ),
        );
      },
    );
  }

  // ====================== EDIT COMPLAINT ======================
  Future<void> _editComplaintDialog() async {
    final descController = TextEditingController(text: _desc);
    final addressController = TextEditingController(text: _address);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          "Edit Complaint",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Description",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Address",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Save",
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final newDesc = descController.text.trim();
    final newAddr = addressController.text.trim();

    if (newDesc.isEmpty || newAddr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Description & Address cannot be empty")),
      );
      return;
    }

    try {
      setState(() => _loading = true);

      await FirebaseFirestore.instance
          .collection("complaints")
          .doc(widget.complaintId)
          .update({"description": newDesc, "address": newAddr});

      setState(() {
        _desc = newDesc;
        _address = newAddr;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complaint updated ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Edit failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ====================== DELETE COMPLAINT ======================
  Future<void> _deleteComplaint() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          "Delete Complaint?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete",
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _loading = true);

      await FirebaseFirestore.instance
          .collection("complaints")
          .doc(widget.complaintId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complaint deleted 🗑️")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ====================== STATUS PROGRESS UI ======================
  Widget _statusProgress() {
    final step = _statusStep(_status);

    Widget stepTile({
      required String title,
      required bool active,
      required Color color,
      required IconData icon,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: active
                  ? color.withOpacity(0.25)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? color.withOpacity(0.65)
                    : Colors.white.withOpacity(0.12),
              ),
            ),
            child: Icon(icon, color: active ? color : Colors.white38, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      );
    }

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _title("Status Progress"),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(_status).withOpacity(0.20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _statusColor(_status).withOpacity(0.50),
                  ),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    color: _statusColor(_status),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          stepTile(
            title: "Pending",
            active: step >= 1,
            color: const Color(0xFFF59E0B),
            icon: Icons.hourglass_bottom_rounded,
          ),
          const SizedBox(height: 10),
          stepTile(
            title: "In Progress",
            active: step >= 2,
            color: const Color(0xFF60A5FA),
            icon: Icons.build_circle_outlined,
          ),
          const SizedBox(height: 10),
          stepTile(
            title: "Fixed / Verified",
            active: step >= 3,
            color: const Color(0xFF22C55E),
            icon: Icons.verified_rounded,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    color: Colors.white54, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Status is controlled by Admin / Authority. Citizen cannot edit.",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12.2,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
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

  // ====================== BUILD ======================
  @override
  Widget build(BuildContext context) {
    final dateText = _createdAt == null
        ? "Just now"
        : DateFormat("dd MMM yyyy, hh:mm a").format(_createdAt!);

    final statusColor = _statusColor(_status);
    final canVerify = _status.toLowerCase().contains("fixed");

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
              // TOP BAR
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: "Delete",
                      onPressed: _loading ? null : _deleteComplaint,
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                    ),
                    IconButton(
                      tooltip: "Edit",
                      onPressed: _loading ? null : _editComplaintDialog,
                      icon: const Icon(Icons.edit_outlined,
                          color: Color(0xFF38BDF8)),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _glassCard(
                          child: Row(
                            children: [
                              Container(
                                height: 54,
                                width: 54,
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.45),
                                  ),
                                ),
                                child: Icon(Icons.report_problem_rounded,
                                    color: statusColor, size: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _title("Complaint Overview"),
                                    const SizedBox(height: 6),
                                    _sub("Submitted on: $dateText"),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.40),
                                  ),
                                ),
                                child: Text(
                                  _status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Timeline
                        _complaintTimeline(),

                        const SizedBox(height: 14),

                        // Upvote card
                        _glassCard(
                          child: Row(
                            children: [
                              const Icon(Icons.thumb_up_alt_rounded,
                                  color: Color(0xFF38BDF8), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Upvotes: $_upvotes",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: (_upvoting || _alreadyUpvoted)
                                    ? null
                                    : _upvoteComplaint,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF38BDF8),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _upvoting
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(
                                        _alreadyUpvoted ? "Upvoted" : "Upvote",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900),
                                      ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ✅ Verify Button (NEW)
                        _glassCard(
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded,
                                  color: Color(0xFF22C55E), size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "Verify Fixed Issue",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed:
                                    (_verifying || !canVerify) ? null : _verifyFixedComplaint,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _verifying
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(
                                        canVerify ? "Verify" : "Not Available",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 820;

                            final left = Column(
                              children: [
                                _glassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _title("Uploaded Photo"),
                                      const SizedBox(height: 12),
                                      GestureDetector(
                                        onTap: () =>
                                            _openImageFullscreen(_imageUrl),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          child: Container(
                                            height: 220,
                                            width: double.infinity,
                                            color:
                                                Colors.white.withOpacity(0.06),
                                            child: _imageUrl.isEmpty
                                                ? const Center(
                                                    child: Text(
                                                      "No image uploaded",
                                                      style: TextStyle(
                                                          color:
                                                              Colors.white60),
                                                    ),
                                                  )
                                                : Image.network(
                                                    _imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __,
                                                            ___) =>
                                                        const Center(
                                                      child: Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                        color: Colors.white54,
                                                        size: 40,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _glassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _title("Description"),
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.06),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.12),
                                          ),
                                        ),
                                        child: Text(
                                          _desc.isEmpty
                                              ? "No description"
                                              : _desc,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13.5,
                                            height: 1.4,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );

                            final right = Column(
                              children: [
                                _statusProgress(),
                                const SizedBox(height: 14),
                                _glassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _title("Location"),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_rounded,
                                              color: Colors.white54, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _address,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12.8,
                                                height: 1.35,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        child: Container(
                                          height: 220,
                                          color: Colors.white.withOpacity(0.06),
                                          child: (_lat == null || _lng == null)
                                              ? const Center(
                                                  child: Text(
                                                    "No location data available",
                                                    style: TextStyle(
                                                        color: Colors.white60),
                                                  ),
                                                )
                                              : GoogleMap(
                                                  initialCameraPosition:
                                                      CameraPosition(
                                                    target:
                                                        LatLng(_lat!, _lng!),
                                                    zoom: 15,
                                                  ),
                                                  markers: {
                                                    Marker(
                                                      markerId: const MarkerId(
                                                          "complaintLocation"),
                                                      position:
                                                          LatLng(_lat!, _lng!),
                                                    )
                                                  },
                                                  zoomControlsEnabled: false,
                                                  myLocationButtonEnabled:
                                                      false,
                                                  compassEnabled: false,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _openInGoogleMaps,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF38BDF8),
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          icon: const Icon(Icons.map_rounded,
                                              size: 18),
                                          label: const Text(
                                            "Open in Google Maps",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: left),
                                  const SizedBox(width: 14),
                                  Expanded(child: right),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                left,
                                const SizedBox(height: 14),
                                right,
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        const Center(
                          child: Text(
                            "© CivicFix 2026",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

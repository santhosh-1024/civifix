import 'dart:typed_data';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/cloudinary_service.dart';

class CreateComplaintScreen extends StatefulWidget {
  const CreateComplaintScreen({super.key});

  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  // controllers
  final _descController = TextEditingController();
  final _addressController = TextEditingController();

  // form data
  String _issueType = "Pothole";
  bool _useCurrentLocation = false;

  double? _lat;
  double? _lng;

  // image
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  // ui
  bool _loading = false;
  String? _error;

  GoogleMapController? _mapController;

  // ⭐ Duplicate Detection Preview
  bool _ignoreDuplicateAndSubmit = false;
  bool _checkingDuplicate = false;
  QueryDocumentSnapshot? _similarDoc;
  double? _similarDistanceMeters;

  final List<String> issueTypes = [
    "Pothole",
    "Street Light",
    "Garbage",
    "Water Leakage",
    "Drainage",
    "Other",
  ];

  @override
  void dispose() {
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ====================== ADDRESS (Reverse Geocoding) ======================
  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isEmpty) return "Unknown location";

      final p = placemarks.first;

      final parts = [
        p.name,
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
        p.postalCode,
        p.country,
      ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();

      return parts.join(", ");
    } catch (e) {
      return "Unable to fetch address";
    }
  }

  // ====================== IMAGE PICK (Web + Mobile) ======================
  Future<void> _pickImage() async {
    try {
      setState(() => _error = null);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // IMPORTANT for WEB
      );

      if (result == null) return;

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null) {
        setState(() => _error = "Failed to read image file.");
        return;
      }

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() => _error = "Image pick failed: $e");
    }
  }

  // ====================== CURRENT LOCATION ======================
  Future<void> _pickCurrentLocation() async {
    try {
      setState(() {
        _error = null;
        _loading = true;
      });

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = "Location service is OFF. Please enable it.";
          _loading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = "Location permission denied forever. Enable in settings.";
          _loading = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = pos.latitude;
      final lng = pos.longitude;

      setState(() {
        _lat = lat;
        _lng = lng;
      });

      final addr = await _getAddressFromLatLng(lat, lng);

      if (!mounted) return;

      setState(() {
        _addressController.text = addr;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
      );

      // ⭐ after location is picked -> check duplicates
      await _checkSimilarComplaint();
    } catch (e) {
      setState(() => _error = "Location error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ====================== DISTANCE (Haversine) ======================
  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  // ====================== DUPLICATE DETECTION ======================
  Future<void> _checkSimilarComplaint() async {
    try {
      if (_lat == null || _lng == null) return;

      setState(() {
        _checkingDuplicate = true;
      });

      // Fetch recent complaints (limit for speed)
      final snap = await FirebaseFirestore.instance
          .collection("complaints")
          .orderBy("createdAt", descending: true)
          .limit(80)
          .get();

      QueryDocumentSnapshot? best;
      double? bestDist;

      for (final doc in snap.docs) {
        final data = doc.data();

        final type = (data["type"] ?? "").toString();
        if (type != _issueType) continue;

        final status = (data["status"] ?? "Pending").toString().toLowerCase();
        if (status.contains("fixed")) continue;

        final lat = data["lat"];
        final lng = data["lng"];
        if (lat is! num || lng is! num) continue;

        final dist = _distanceMeters(
          _lat!,
          _lng!,
          lat.toDouble(),
          lng.toDouble(),
        );

        if (dist <= 200) {
          if (best == null || dist < (bestDist ?? 999999)) {
            best = doc;
            bestDist = dist;
          }
        }
      }

      setState(() {
        _similarDoc = best;
        _similarDistanceMeters = bestDist;
        _ignoreDuplicateAndSubmit = false;
      });
    } catch (e) {
      // do nothing hard fail
    } finally {
      if (mounted) {
        setState(() {
          _checkingDuplicate = false;
        });
      }
    }
  }

  // ====================== UPVOTE SIMILAR ======================
  Future<void> _upvoteSimilarComplaint() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_similarDoc == null) return;

      final ref = FirebaseFirestore.instance
          .collection("complaints")
          .doc(_similarDoc!.id);

      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>;

        final List<dynamic> upvotedBy = (data["upvotedBy"] ?? []) as List;
        if (upvotedBy.contains(user.uid)) {
          return;
        }

        txn.update(ref, {
          "upvotes": FieldValue.increment(1),
          "upvotedBy": FieldValue.arrayUnion([user.uid]),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upvoted existing complaint 👍")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upvote failed: $e")));
    }
  }

  // ====================== SUBMIT ======================
  Future<void> _submitComplaint() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _error = "Not logged in.");
        return;
      }

      if (_descController.text.trim().isEmpty) {
        setState(() => _error = "Please enter description.");
        return;
      }

      if (_selectedImageBytes == null) {
        setState(() => _error = "Please upload an image.");
        return;
      }

      if (_lat == null || _lng == null) {
        setState(() => _error = "Please select location on map.");
        return;
      }

      if (_addressController.text.trim().isEmpty) {
        setState(() => _error = "Address is empty. Please enter address.");
        return;
      }

      // ⭐ If duplicate exists and user didn't ignore -> block submit
      if (_similarDoc != null && !_ignoreDuplicateAndSubmit) {
        setState(() {
          _error =
              "Similar complaint exists nearby. Please upvote it or choose Create New Anyway.";
        });
        return;
      }

      // Upload image to Cloudinary (your service)
      final imgUrl = await CloudinaryService.uploadImage(
        _selectedImageBytes!,
      ).timeout(const Duration(seconds: 30));

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection("complaints")
          .add({
            "userId": user.uid,
            "userEmail": user.email ?? "",
            "type": _issueType,
            "description": _descController.text.trim(),
            "imageUrl": imgUrl,
            "lat": _lat,
            "lng": _lng,
            "address": _addressController.text.trim(),
            "status": "Pending",
            "priority": "Medium",
            "upvotes": 0,
            "upvotedBy": [],
            "createdAt": FieldValue.serverTimestamp(),
          });

      // ⭐ Notification entry (works now in Firestore)
      await FirebaseFirestore.instance.collection("notifications").add({
        "userId": user.uid,
        "title": "Complaint Submitted ✅",
        "message": "Your complaint has been submitted successfully.",
        "complaintId": docRef.id,
        "createdAt": FieldValue.serverTimestamp(),
        "read": false,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Complaint submitted ✅")));

      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = "Submit failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ====================== UI HELPERS ======================
  Widget _title(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ====================== SIMILAR PREVIEW CARD ======================
  Widget _similarComplaintCard() {
    if (_similarDoc == null) return const SizedBox.shrink();

    final data = _similarDoc!.data() as Map<String, dynamic>;
    final type = (data["type"] ?? "Unknown").toString();
    final address = (data["address"] ?? "No address").toString();
    final status = (data["status"] ?? "Pending").toString();
    final upvotes = (data["upvotes"] ?? 0);

    final dist = _similarDistanceMeters ?? 0;

    return _HoverGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "⚠️ Similar complaint exists nearby",
            style: TextStyle(
              color: Color(0xFFF59E0B),
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  type,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                "Distance: ${dist.toStringAsFixed(0)}m",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _upvoteSimilarComplaint,
                  icon: const Icon(Icons.thumb_up_alt_rounded),
                  label: const Text(
                    "Upvote Existing",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _ignoreDuplicateAndSubmit = true;
                            _error = null;
                          });
                        },
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "Create New Anyway",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_ignoreDuplicateAndSubmit)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withOpacity(0.35)),
                ),
                child: const Text(
                  "You chose to create a new complaint anyway ✅",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.12, end: 0);
  }

  // ====================== BUILD ======================
  @override
  Widget build(BuildContext context) {
    final initialLatLng = LatLng(_lat ?? 11.0168, _lng ?? 76.9558);

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        "Create Complaint",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ScrollConfiguration(
                  behavior: const _BouncyScrollBehavior(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 820;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Card
                              _HoverGlassCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _title("Report an Issue"),
                                        const SizedBox(height: 6),
                                        const Text(
                                          "Upload photo • Choose location • Submit quickly",
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(duration: 500.ms)
                                  .slideY(
                                    begin: 0.18,
                                    end: 0,
                                    curve: Curves.easeOutCubic,
                                  )
                                  .blur(
                                    begin: const Offset(0, 10),
                                    end: Offset.zero,
                                  ),

                              const SizedBox(height: 14),

                              // ⭐ Similar complaint preview card here
                              if (_checkingDuplicate)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Color(0xFF38BDF8),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        "Checking for similar complaints...",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn(duration: 300.ms),

                              if (!_checkingDuplicate) _similarComplaintCard(),

                              const SizedBox(height: 14),

                              isWide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _leftPanel(initialLatLng),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _rightPanel(initialLatLng),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _leftPanel(initialLatLng),
                                        const SizedBox(height: 14),
                                        _rightPanel(initialLatLng),
                                      ],
                                    ),

                              const SizedBox(height: 14),

                              if (_error != null)
                                Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.35),
                                        ),
                                      ),
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 350.ms)
                                    .slideY(begin: 0.12, end: 0),

                              const SizedBox(height: 14),

                              _PressScale(
                                    onTap: _loading ? null : _submitComplaint,
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: ElevatedButton.icon(
                                        onPressed: _loading
                                            ? null
                                            : _submitComplaint,
                                        icon: _loading
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Colors.black,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.check_circle_outline,
                                              ),
                                        label: Text(
                                          _loading
                                              ? "Submitting..."
                                              : "Submit Complaint",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF38BDF8,
                                          ),
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .animate(delay: 250.ms)
                                  .fadeIn(duration: 500.ms)
                                  .scale(
                                    begin: const Offset(0.97, 0.97),
                                    end: const Offset(1, 1),
                                  ),

                              const SizedBox(height: 16),

                              const Center(
                                child: Text(
                                  "© CivicFix 2026",
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
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

  // ====================== LEFT PANEL ======================
  Widget _leftPanel(LatLng initialLatLng) {
    return Column(
      children: [
        _HoverGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title("Complaint Info"),
                  const SizedBox(height: 14),

                  _label("Issue Type"),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: _issueType,
                    dropdownColor: const Color(0xFF111827),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.category_outlined,
                        color: Colors.white60,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF38BDF8),
                          width: 1.6,
                        ),
                      ),
                    ),
                    items: issueTypes
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) async {
                      if (val == null) return;
                      setState(() => _issueType = val);

                      // ⭐ re-check duplicates when issue type changes
                      await _checkSimilarComplaint();
                    },
                  ),

                  const SizedBox(height: 14),

                  _label("Description"),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _descController,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Explain the issue clearly...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.12),
                        ),
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
              ),
            )
            .animate(delay: 120.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.18, end: 0, curve: Curves.easeOutCubic)
            .blur(begin: const Offset(0, 10), end: Offset.zero),

        const SizedBox(height: 14),

        _HoverGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title("Upload Evidence"),
                  const SizedBox(height: 14),

                  _HoverBox(
                    borderRadius: 18,
                    onTap: _loading ? null : _pickImage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: _selectedImageBytes == null
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      color: Colors.white70,
                                      size: 40,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      "Tap to upload image",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "JPG / PNG supported",
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  ],
                                ),
                              )
                            : Image.memory(
                                _selectedImageBytes!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                      ),
                    ),
                  ),

                  if (_selectedImageName != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.image_rounded,
                          color: Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _selectedImageName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: "Remove",
                          onPressed: _loading
                              ? null
                              : () {
                                  setState(() {
                                    _selectedImageBytes = null;
                                    _selectedImageName = null;
                                  });
                                },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )
            .animate(delay: 240.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.18, end: 0, curve: Curves.easeOutCubic)
            .blur(begin: const Offset(0, 10), end: Offset.zero),
      ],
    );
  }

  // ====================== RIGHT PANEL ======================
  Widget _rightPanel(LatLng initialLatLng) {
    return _HoverGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title("Location & Address"),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _useCurrentLocation,
                            onChanged: _loading
                                ? null
                                : (val) async {
                                    setState(() {
                                      _useCurrentLocation = val ?? false;
                                    });
                                    if (_useCurrentLocation) {
                                      await _pickCurrentLocation();
                                    }
                                  },
                            activeColor: const Color(0xFF38BDF8),
                          ),
                          const Expanded(
                            child: Text(
                              "Use my current location",
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _pickCurrentLocation,
                      icon: const Icon(Icons.my_location, color: Colors.white),
                      label: const Text(
                        "Locate",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.25)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _HoverBox(
                borderRadius: 18,
                onTap: null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 240,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: initialLatLng,
                        zoom: 14,
                      ),
                      onMapCreated: (c) => _mapController = c,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onTap: (latLng) async {
                        setState(() {
                          _lat = latLng.latitude;
                          _lng = latLng.longitude;
                        });

                        final addr = await _getAddressFromLatLng(
                          latLng.latitude,
                          latLng.longitude,
                        );

                        if (!mounted) return;
                        setState(() {
                          _addressController.text = addr;
                        });

                        // ⭐ check duplicates when map tap changes location
                        await _checkSimilarComplaint();
                      },
                      markers: {
                        if (_lat != null && _lng != null)
                          Marker(
                            markerId: const MarkerId("selected"),
                            position: LatLng(_lat!, _lng!),
                          ),
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _label("Address (Auto-filled + Editable)"),
              const SizedBox(height: 8),

              TextField(
                controller: _addressController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter address here...",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF38BDF8),
                      width: 1.6,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(delay: 360.ms)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.18, end: 0, curve: Curves.easeOutCubic)
        .blur(begin: const Offset(0, 10), end: Offset.zero);
  }
}

// ===================== HOVER GLASS CARD =====================
class _HoverGlassCard extends StatefulWidget {
  final Widget child;
  const _HoverGlassCard({required this.child});

  @override
  State<_HoverGlassCard> createState() => _HoverGlassCardState();
}

class _HoverGlassCardState extends State<_HoverGlassCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_hover ? 0.10 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hover
                ? const Color(0xFF38BDF8).withOpacity(0.40)
                : Colors.white.withOpacity(0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_hover ? 0.55 : 0.35),
              blurRadius: _hover ? 35 : 25,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: widget.child),
      ),
    );
  }
}

// ===================== HOVER BOX (IMAGE + MAP) =====================
class _HoverBox extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final VoidCallback? onTap;

  const _HoverBox({required this.child, this.borderRadius = 18, this.onTap});

  @override
  State<_HoverBox> createState() => _HoverBoxState();
}

class _HoverBoxState extends State<_HoverBox> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _hover
                  ? const Color(0xFF38BDF8).withOpacity(0.45)
                  : Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_hover ? 0.55 : 0.35),
                blurRadius: _hover ? 30 : 20,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ===================== PRESS SCALE BUTTON EFFECT =====================
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) {
              setState(() => _down = true);
            },
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _down = false);
              widget.onTap?.call();
            },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _down ? 0.97 : 1.0,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ===================== BOUNCY SCROLL =====================
class _BouncyScrollBehavior extends MaterialScrollBehavior {
  const _BouncyScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

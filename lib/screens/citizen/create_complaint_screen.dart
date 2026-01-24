import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'package:civicfix/services/cloudinary_service.dart';

class CreateComplaintScreen extends StatefulWidget {
  const CreateComplaintScreen({super.key});

  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  Uint8List? selectedImageBytes;

  final _descController = TextEditingController();

  String _issueType = "Pothole";
  bool _loading = false;
  String? _error;

  double? _lat;
  double? _lng;

  final List<String> _issueTypes = [
    "Pothole",
    "Streetlight",
    "Garbage",
    "Illegal Dumping",
  ];

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      setState(() {
        selectedImageBytes = bytes;
      });
    } catch (e) {
      setState(() {
        _error = "Image pick failed: $e";
      });
    }
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error = "Location service is OFF. Turn it ON.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _error = "Location permission denied forever.");
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to get location: $e";
      });
    }
  }

  Future<String> _uploadImage(Uint8List bytes) async {
    return await CloudinaryService.uploadImage(bytes);
  }

  Future<void> _submitComplaint() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _error = "Not logged in");
        return;
      }

      if (_descController.text.trim().isEmpty) {
        setState(() => _error = "Please enter description");
        return;
      }

      if (selectedImageBytes == null) {
        setState(() => _error = "Please select an image");
        return;
      }

      // Location required
      if (_lat == null || _lng == null) {
        await _getLocation();
        if (_lat == null || _lng == null) {
          setState(() => _error = "Location not found");
          return;
        }
      }

      // Upload to Cloudinary
      final imgUrl = await _uploadImage(selectedImageBytes!);

      // Save to Firestore
      await FirebaseFirestore.instance.collection("complaints").add({
        "userId": user.uid,
        "userEmail": user.email ?? "",
        "type": _issueType,
        "description": _descController.text.trim(),
        "imageUrl": imgUrl,
        "lat": _lat,
        "lng": _lng,
        "status": "Reported",
        "priority": "Medium",
        "upvotes": 0,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complaint submitted ✅")),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = "Submit failed: $e";
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
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF0B1220),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Bar
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Report an Issue",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Card
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
                            "Complaint Details",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Issue type dropdown
                          _label("Issue Type"),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _issueType,
                                dropdownColor: const Color(0xFF0F172A),
                                style: const TextStyle(color: Colors.white),
                                iconEnabledColor: Colors.white70,
                                items: _issueTypes.map((t) {
                                  return DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() => _issueType = val);
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Description
                          _label("Description"),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _descController,
                            maxLines: 4,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Explain the issue clearly...",
                              hintStyle: const TextStyle(color: Colors.white38),
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

                          const SizedBox(height: 14),

                          // Image picker
                          _label("Upload Photo"),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _loading ? null : _pickImage,
                            child: Container(
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Center(
                                child: selectedImageBytes == null
                                    ? const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_outlined,
                                              color: Colors.white70, size: 36),
                                          SizedBox(height: 8),
                                          Text(
                                            "Tap to select image",
                                            style: TextStyle(color: Colors.white60),
                                          ),
                                        ],
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.memory(
                                          selectedImageBytes!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Location button
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _loading ? null : _getLocation,
                              icon: const Icon(Icons.my_location, color: Colors.white),
                              label: Text(
                                _lat == null
                                    ? "Get Current Location"
                                    : "Location Captured ✅",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
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

                          const SizedBox(height: 12),

                          if (_error != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.withOpacity(0.35)),
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

                          // Submit button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submitComplaint,
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
                                      "Submit Complaint",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Center(
                      child: Text(
                        "© CivicFix 2026",
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

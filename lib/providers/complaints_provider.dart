import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/complaint.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../services/duplicate_service.dart';

class ComplaintsProvider extends ChangeNotifier {
  final firestore = FirestoreService();
  final storage = StorageService();
  final location = LocationService();
  final duplicate = DuplicateService();

  bool submitting = false;

  Future<List<Complaint>> checkDuplicates(double lat, double lng) async {
    return duplicate.findNearbyOpenComplaints(lat: lat, lng: lng, radiusMeters: 50);
  }

  Future<String> submitComplaint({
    required String userId,
    required String type,
    required String description,
    required File imageFile,
  }) async {
    submitting = true;
    notifyListeners();

    final pos = await location.getCurrentLocation();
    final imgUrl = await storage.uploadComplaintImage(imageFile, folder: "complaints_before");

    final now = DateTime.now();
    final complaint = Complaint(
      id: const Uuid().v4(),
      userId: userId,
      type: type,
      description: description,
      status: "reported",
      priority: "medium",
      imageUrl: imgUrl,
      upvotes: 0,
      isOpen: true,
      lat: pos.latitude,
      lng: pos.longitude,
      createdAt: now,
      updatedAt: now,
    );

    final id = await firestore.createComplaint(complaint);

    submitting = false;
    notifyListeners();
    return id;
  }
}

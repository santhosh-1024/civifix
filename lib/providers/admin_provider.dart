import 'dart:io';
import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class AdminProvider extends ChangeNotifier {
  final analytics = AnalyticsService();
  final firestore = FirestoreService();
  final storage = StorageService();

  Map<String, dynamic>? stats;
  bool loadingStats = false;

  Future<void> loadStats() async {
    loadingStats = true;
    notifyListeners();
    stats = await analytics.getAdminStats();
    loadingStats = false;
    notifyListeners();
  }

  Future<void> updateComplaintStatus({
    required String complaintId,
    required String adminUid,
    String? status,
    String? priority,
    String? department,
    String? assignedTeam,
    String? assignedTo,
    String? remarks,
    File? afterImage,
    bool? isOpen,
  }) async {
    String? afterUrl;
    if (afterImage != null) {
      afterUrl = await storage.uploadComplaintImage(afterImage, folder: "complaints_after");
    }

    await firestore.adminUpdateComplaint(
  complaintId: complaintId,
  status: status,
  assignedTo: assignedTo,
  priority: priority,
  remarks: remarks,
  afterFixImageUrl: afterUrl,
);

  }
}

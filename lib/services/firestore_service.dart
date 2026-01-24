import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<String> createComplaint(Complaint complaint) async {
    final doc = await _db.collection("complaints").add(complaint.toMap());
    return doc.id;
  }

  Future<void> adminUpdateComplaint({
    required String complaintId,
    String? status,
    String? assignedTo,
    String? priority,
    String? remarks,
    String? afterFixImageUrl,
  }) async {
    final ref = _db.collection("complaints").doc(complaintId);

    Map<String, dynamic> updateData = {
      "updatedAt": FieldValue.serverTimestamp(),
    };

    if (status != null) updateData["status"] = status;
    if (assignedTo != null) updateData["assignedTo"] = assignedTo;
    if (priority != null) updateData["priority"] = priority;
    if (remarks != null) updateData["adminRemarks"] = remarks;
    if (afterFixImageUrl != null) updateData["afterFixImageUrl"] = afterFixImageUrl;

    await ref.update(updateData);

    // add status log
    await _db.collection("status_logs").add({
      "complaintId": complaintId,
      "status": status ?? "Updated",
      "timestamp": FieldValue.serverTimestamp(),
      "remarks": remarks ?? "",
    });
  }
}

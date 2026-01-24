import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  final _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getAdminStats() async {
    final snap = await _db.collection("complaints").get();

    int total = snap.docs.length;
    int pending = 0;

    for (var doc in snap.docs) {
      final status = doc.data()["status"] ?? "Reported";
      if (status != "Closed" && status != "Resolved") {
        pending++;
      }
    }

    return {
      "total": total,
      "pending": pending,
    };
  }
}

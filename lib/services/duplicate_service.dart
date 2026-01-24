import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint.dart';

class DuplicateService {
  final _db = FirebaseFirestore.instance;

  Future<List<Complaint>> findNearbyOpenComplaints({
    required double lat,
    required double lng,
    required double radiusMeters,
  }) async {
    final snap = await _db.collection("complaints").get();

    List<Complaint> results = [];

    for (var doc in snap.docs) {
      final data = doc.data();

      final status = (data["status"] ?? "Reported").toString();

      // Only check open complaints (not closed/resolved)
      if (status == "Closed" || status == "Resolved") continue;

      final location = data["location"];
      if (location == null) continue;

      final double cLat = (location["lat"] ?? 0).toDouble();
      final double cLng = (location["lng"] ?? 0).toDouble();

      final dist = _distanceInMeters(lat, lng, cLat, cLng);

      if (dist <= radiusMeters) {
        results.add(Complaint.fromMap(doc.id, data));
      }
    }

    return results;
  }

  double _distanceInMeters(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Earth radius in meters

    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  double _degToRad(double deg) {
    return deg * (pi / 180);
  }
}

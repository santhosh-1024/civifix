import 'package:cloud_firestore/cloud_firestore.dart';

class PointsService {
  static Future<void> addPoints({
    required String userId,
    required int pointsToAdd,
  }) async {
    final userRef =
        FirebaseFirestore.instance.collection("users").doc(userId);

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(userRef);

      if (!snap.exists) {
        // Create user points if not exists
        txn.set(userRef, {
          "points": pointsToAdd,
          "lastPoints": 0,
          "badge": "Bronze Reporter",
        });
        return;
      }

      final data = snap.data()!;
      final currentPoints = (data["points"] ?? 0) as int;

      final newPoints = currentPoints + pointsToAdd;

      txn.update(userRef, {
        "points": newPoints,
        "badge": _badgeForPoints(newPoints),
      });
    });
  }

  static String _badgeForPoints(int points) {
    if (points >= 100) return "🥇 Gold Civic Hero";
    if (points >= 50) return "🥈 Silver Helper";
    return "🥉 Bronze Reporter";
  }
}

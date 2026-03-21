import 'package:firebase_database/firebase_database.dart';

class LeaderboardEntry {
  final String name;
  final double score;
  final String email;

  LeaderboardEntry({required this.name, required this.score, required this.email});
}

class LeaderboardService {
  final _db = FirebaseDatabase.instance.ref();

  Stream<List<LeaderboardEntry>> getExamLeaderboard(String examId) {
    return _db.child('attempts').orderByChild('examId').equalTo(examId).onValue.map((event) {
      final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
      if (data == null) return [];

      List<LeaderboardEntry> entries = [];
      data.forEach((key, value) {
        final attempt = Map<String, dynamic>.from(value);
        // Only include completed/graded exams
        if (attempt['status'] == 'completed') {
          entries.add(LeaderboardEntry(
            name: attempt['candidate']?['name'] ?? 'Anonymous',
            email: attempt['candidate']?['email'] ?? '',
            score: double.tryParse(attempt['totalPoints'].toString()) ?? 0.0,
          ));
        }
      });

      // Sort by score descending
      entries.sort((a, b) => b.score.compareTo(a.score));
      return entries;
    });
  }
}
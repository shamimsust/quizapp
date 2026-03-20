import 'dart:math';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';

class TokenService {
  final _db = FirebaseDatabase.instance.ref();

  String _generateToken(int bytes) {
    final rng = Random.secure();
    final b = List<int>.generate(bytes, (_) => rng.nextInt(256));
    // Generates a URL-safe random string
    return base64Url.encode(b).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');
  }

  Future<String> createToken(String examId) async {
    final token = _generateToken(12); // Slightly shorter for easier sharing
    await _db.child('examTokens/$token').set({
      'examId': examId,
      'createdAt': ServerValue.timestamp,
      'usedCount': 0,
      'expiresAt': null, // Can be added later if needed
    });
    return token;
  }

  // Stream of all exams to populate the dropdown
  Stream<Map<String, String>> watchAllExams() {
    return _db.child('exams').onValue.map((event) {
      final Map<String, String> exams = {};
      final data = event.snapshot.value as Map?;
      if (data != null) {
        data.forEach((key, value) {
          final examData = Map.from(value as Map);
          exams[key] = examData['title'] ?? 'Untitled Exam';
        });
      }
      return exams;
    });
  }
}
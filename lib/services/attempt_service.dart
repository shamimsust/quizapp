import 'package:firebase_database/firebase_database.dart';
import '../models/attempt.dart'; //

class AttemptService {
  final _db = FirebaseDatabase.instance.ref();

  /// Starts a new attempt and calculates the endTime based on durationMs
  Future<String> startAttempt({
    required String examId,
    required String uid,
    required Map<String, dynamic> candidate,
    required int durationMs,
    String? token,
  }) async {
    final ref = _db.child('attempts').push();
    
    // Get the current local time to calculate the offset
    final int start = DateTime.now().millisecondsSinceEpoch;
    final int end = start + durationMs; //

    await ref.set({
      'examId': examId,
      'userId': uid,
      'candidate': candidate,
      'status': 'in_progress', //
      'startTime': start,
      'endTime': end, 
      'createdFromToken': token,
      'createdAt': ServerValue.timestamp,
    });

    // If a token was used, mark it as used in the database
    if (token != null) {
      await _db.child('examTokens/$token/usedCount').set(ServerValue.increment(1));
    }

    return ref.key!;
  }

  /// Saves or updates an MCQ answer in a sub-node
  Future<void> saveMcqAnswer(String attemptId, String qId, List<String> selected) async {
    await _db.child('attemptAnswers/$attemptId/$qId').set({
      'type': 'mcq',
      'selected': selected,
      'savedAt': ServerValue.timestamp,
    });
  }

  /// Saves a written/LaTeX answer
  Future<void> saveWrittenAnswer(String attemptId, String qId, String latex, {String? text}) async {
    await _db.child('attemptAnswers/$attemptId/$qId').set({
      'type': 'written',
      'latexAnswer': latex,
      'textAnswer': text,
      'savedAt': ServerValue.timestamp,
    });
  }

  /// Finalizes the attempt and updates the status
  Future<void> submit(String attemptId) async {
    await _db.child('attempts/$attemptId').update({
      'status': 'submitted',
      'submittedAt': ServerValue.timestamp,
    });
  }

  /// Streams the current attempt data to the UI
  Stream<Attempt> watchAttempt(String attemptId) => 
    _db.child('attempts/$attemptId').onValue.map((e) {
      final data = Map.from(e.snapshot.value as Map);
      return Attempt.fromJson(attemptId, data);
    });
}
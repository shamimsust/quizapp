import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'; 
import '../models/exam.dart';
import '../models/question.dart'; 

class ExamService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Fetches general exam metadata (Title, Duration, etc.)
  /// Uses the secure .forStudent factory.
  Future<Exam?> getExamForStudent(String examId) async {
    try {
      final snapshot = await _db.child('exams/$examId').get();
      
      if (snapshot.exists) {
        // Casting to Map<String, dynamic> is safer for Dart models
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        
        // Calling your specialized student-facing factory
        return Exam.forStudent(examId, data);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching exam metadata: $e");
      return null;
    }
  }

  /// Streams questions in real-time for the Exam Room.
  /// Automatically updates if a question is modified during the test.
  Stream<List<Question>> watchQuestionsForStudent(String examId) {
    return _db.child('exams/$examId/questions').onValue.map((event) {
      final List<Question> questions = [];
      final data = event.snapshot.value;
      
      if (data is Map) {
        data.forEach((key, value) {
          final qData = Map<String, dynamic>.from(value as Map);
          
          // Securely mapping questions without correct answer keys
          questions.add(Question.forStudent(key.toString(), qData));
        });
      }
      return questions;
    });
  }
}
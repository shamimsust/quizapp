import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../models/token.dart';

class ExamService {
  final _db = FirebaseDatabase.instance.ref();

  // --- Admin Methods ---

  /// Creates a new exam in the /exams node
  Future<String> createExam(Exam exam) async {
    _ensureAuthenticated();
    final ref = _db.child('exams').push();
    await ref.set(exam.toJson());
    return ref.key!;
  }

  /// FIX: Writes to /exams/$examId/questions to match your Security Rules
  Future<void> addQuestion(String examId, Question q) async {
    _ensureAuthenticated();
    
    // We point to the specific exam's questions sub-node
    // Your rules allow .write on /exams/$examId for admins
    final ref = _db.child('exams/$examId/questions').push();
    
    final data = q.toJson();
    data['id'] = ref.key; // Store the auto-generated ID inside the object
    
    await ref.set(data);
  }

  // --- Student & Security Methods ---

  /// Validates a token code and returns the examId if valid
  Future<String?> validateToken(String tokenCode) async {
    final snapshot = await _db.child('examTokens/$tokenCode').get();
    if (!snapshot.exists) return null;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final token = ExamToken.fromJson(tokenCode, data);

    // usedCount and expiry logic
    if (token.usedCount > 0) return null; 
    
    return token.examId;
  }

  /// Fetches exam metadata without correct answers
  Future<Exam?> getExamForStudent(String examId) async {
    final snapshot = await _db.child('exams/$examId').get();
    if (!snapshot.exists) return null;
    
    return Exam.forStudent(examId, Map<String, dynamic>.from(snapshot.value as Map));
  }

  /// Streams questions from the correct /exams/$examId/questions node
  Stream<List<Question>> watchQuestionsForStudent(String examId) {
    return _db.child('exams/$examId/questions').onValue.map((e) {
      final raw = (e.snapshot.value as Map?) ?? {};
      return raw.entries.map((entry) {
        return Question.forStudent(entry.key.toString(), Map<String, dynamic>.from(entry.value as Map));
      }).toList();
    });
  }

  // --- Real-time Watchers ---

  Stream<Exam> watchExam(String examId) {
    return _db.child('exams/$examId').onValue.map((e) {
      if (e.snapshot.value == null) throw Exception("Exam not found");
      return Exam.fromJson(examId, Map<String, dynamic>.from(e.snapshot.value as Map));
    });
  }

  // --- Private Helpers ---

  /// Internal check to prevent unauthenticated database calls
  void _ensureAuthenticated() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Authentication required for this action.");
    }
  }
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/exam_service.dart';
import '../models/exam.dart';
import '../models/question.dart';

// 1. Service Provider
// This provides a single instance of your ExamService to the rest of the app.
final examServiceProvider = Provider<ExamService>((ref) => ExamService());

// 2. Metadata Provider (Used by ExamInstructionsScreen)
// We use .family because we need to pass the specific 'examId'.
// This calls the secure .forStudent() factory in your service.
final examProvider = FutureProvider.family<Exam?, String>((ref, examId) async {
  final cleanId = examId.trim();
  if (cleanId.isEmpty) return null;

  final service = ref.watch(examServiceProvider);
  return await service.getExamForStudent(cleanId);
});

// 3. Questions Stream Provider (Used by ExamRoomScreen)
// This listens for real-time changes to questions during the exam.
final examQuestionsProvider = StreamProvider.family<List<Question>, String>((ref, examId) {
  final cleanId = examId.trim();
  if (cleanId.isEmpty) return Stream.value([]);

  final service = ref.watch(examServiceProvider);
  return service.watchQuestionsForStudent(cleanId);
});

// 4. Active Exam ID Management
// Helps track which exam the student is currently taking across different screens.
class ActiveExamId extends Notifier<String?> {
  @override
  String? build() => null;
  
  void set(String? id) => state = id;
  void clear() => state = null;
}

final activeExamIdProvider = NotifierProvider<ActiveExamId, String?>(ActiveExamId.new);

// 5. Current Exam Helper
// A shortcut to get the metadata of the exam currently being taken.
final currentExamProvider = FutureProvider<Exam?>((ref) async {
  final activeId = ref.watch(activeExamIdProvider);
  if (activeId == null) return null;
  
  return ref.watch(examProvider(activeId).future);
});
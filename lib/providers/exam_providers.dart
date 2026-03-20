import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/exam_service.dart';
import '../models/exam.dart';
import '../models/question.dart';

// 1. Service Provider
final examServiceProvider = Provider<ExamService>((ref) => ExamService());

// 2. Active ID Management
class ActiveExamId extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}
final activeExamIdProvider = NotifierProvider<ActiveExamId, String?>(ActiveExamId.new);

// 3. Specific Exam Fetcher (Used by Instructions Screen)
final examProvider = FutureProvider.family<Exam?, String>((ref, examId) async {
  final cleanId = examId.trim();
  if (cleanId.isEmpty) return null;

  final service = ref.watch(examServiceProvider);
  // Fetches basic meta-data like title and duration
  return await service.getExamForStudent(cleanId);
});

// 4. Reactive Questions Stream (Used by Exam Room)
final examQuestionsProvider = StreamProvider.family<List<Question>, String>((ref, examId) {
  final cleanId = examId.trim();
  if (cleanId.isEmpty) return Stream.value([]);

  final service = ref.watch(examServiceProvider);
  return service.watchQuestionsForStudent(cleanId);
});

// 5. Current Exam Shortcut
final currentExamProvider = FutureProvider<Exam?>((ref) async {
  final activeId = ref.watch(activeExamIdProvider);
  if (activeId == null) return null;
  
  // Use .future to wait for the result of the family provider
  return ref.watch(examProvider(activeId).future);
});
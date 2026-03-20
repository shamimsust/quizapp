import 'question.dart';

class Exam {
  final String id;
  final String title;
  final String description;
  final int durationMs;
  final bool containsWritten;
  final List<Question>? questions; //

  Exam({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMs,
    required this.containsWritten,
    this.questions,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'durationMs': durationMs,
        'containsWritten': containsWritten,
        if (questions != null) 'questions': questions!.map((e) => e.toJson()).toList(),
      };

  factory Exam.fromJson(String id, Map data) => Exam(
        id: id,
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        durationMs: data['durationMs'] ?? 0,
        containsWritten: data['containsWritten'] ?? false,
        questions: (data['questions'] as List?)
            ?.map((q) => Question.fromJson(q['id'] ?? '', Map.from(q)))
            .toList(),
      );

  // Security factory for students
  factory Exam.forStudent(String id, Map data) => Exam(
        id: id,
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        durationMs: data['durationMs'] ?? 0,
        containsWritten: data['containsWritten'] ?? false,
        questions: (data['questions'] as List?)
            ?.map((q) => Question.forStudent(q['id'] ?? '', Map.from(q)))
            .toList(),
      );
}
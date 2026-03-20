class Attempt {
  final String id;
  final String examId;
  final String userId;
  final String status; 
  final int startTime;
  final int endTime;
  final Map<String, dynamic>? answers; // Added for tracking
  final double? score; // Added for results

  Attempt({
    required this.id,
    required this.examId,
    required this.userId,
    required this.status,
    required this.startTime,
    required this.endTime,
    this.answers,
    this.score,
  });

  Map<String, dynamic> toJson() => {
        'examId': examId,
        'userId': userId,
        'status': status,
        'startTime': startTime,
        'endTime': endTime,
        if (answers != null) 'answers': answers,
        if (score != null) 'score': score,
      };

  factory Attempt.fromJson(String id, Map data) => Attempt(
        id: id,
        examId: data['examId'] ?? '',
        userId: data['userId'] ?? '',
        status: data['status'] ?? 'in_progress',
        startTime: data['startTime'] ?? 0,
        endTime: data['endTime'] ?? 0,
        answers: data['answers'] != null ? Map<String, dynamic>.from(data['answers']) : null,
        score: (data['score'] as num?)?.toDouble(),
      );
}
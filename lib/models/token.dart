class ExamToken {
  final String token;
  final String examId;
  final int? expiresAt;
  final int usedCount;

  ExamToken({
    required this.token, 
    required this.examId, 
    this.expiresAt, 
    this.usedCount = 0,
  });

  factory ExamToken.fromJson(String token, Map data) => ExamToken(
        token: token,
        examId: data['examId'] ?? '',
        expiresAt: data['expiresAt'],
        usedCount: data['usedCount'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'examId': examId,
        'expiresAt': expiresAt,
        'usedCount': usedCount,
      };
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/latex_text.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String attemptId;
  const ResultScreen({super.key, required this.attemptId});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  Key _refreshKey = UniqueKey();
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('EXAM PERFORMANCE', 
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: true, // Set to true so students can go back to lookup
      ),
      body: RefreshIndicator(
        color: brandBlue,
        onRefresh: () async { setState(() { _refreshKey = UniqueKey(); }); },
        child: FutureBuilder(
          key: _refreshKey,
          future: _fetchFullResultData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: brandBlue));
            }

            if (snapshot.hasError || !snapshot.hasData) return _buildErrorState();

            final results = snapshot.data as Map<String, dynamic>;
            final attempt = results['attempt'];
            final questions = results['questions'] as Map;
            final answers = results['answers'] as Map;

            // STATUS LOGIC: Only 'completed' shows the final grade
            final String status = attempt['status'] ?? 'submitted';
            final bool isPending = status != 'completed'; 
            
            // BP Logic: Prioritize the Rank/Score assigned by admin
            final dynamic score = attempt['score'] ?? 0;
            final num total = attempt['totalPossible'] ?? 0;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    _buildIllustration(isPending, brandBlue),
                    const SizedBox(height: 24),
                    _buildScoreCard(score, total, isPending, brandBlue),
                    
                    const SizedBox(height: 32),
                    
                    _buildActionButton(
                      label: _showDetails ? 'HIDE BREAKDOWN' : 'VIEW DETAILED REVIEW',
                      icon: _showDetails ? Icons.expand_less : Icons.analytics_outlined,
                      color: _showDetails ? Colors.blueGrey : brandBlue,
                      onPressed: () => setState(() => _showDetails = !_showDetails),
                    ),

                    if (_showDetails) ...[
                      const SizedBox(height: 24),
                      _buildDetailedList(questions, answers, brandBlue),
                    ],

                    const SizedBox(height: 16),
                    _buildActionButton(
                      label: 'RETURN TO DASHBOARD',
                      icon: Icons.home_filled,
                      color: const Color(0xFF1E293B),
                      onPressed: () => context.go('/'),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchFullResultData() async {
    final attemptSnap = await FirebaseDatabase.instance.ref('attempts/${widget.attemptId}').get();
    if (!attemptSnap.exists) throw Exception("Attempt not found");
    
    final attemptData = Map<String, dynamic>.from(attemptSnap.value as Map);
    final String examId = attemptData['examId'] ?? '';

    final results = await Future.wait([
      FirebaseDatabase.instance.ref('exams/$examId/questions').get(),
      FirebaseDatabase.instance.ref('attemptAnswers/${widget.attemptId}').get(),
    ]);

    return {
      'attempt': attemptData,
      'questions': (results[0].value as Map?) ?? {},
      'answers': (results[1].value as Map?) ?? {},
    };
  }

  Widget _buildScoreCard(dynamic score, num total, bool isPending, Color brandBlue) {
    // If it's a number, calculate percentage. If it's a string (1st, 2nd), progress is 100%
    final double percent = (score is num && total > 0) ? (score / total) : (isPending ? 0.0 : 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Text(isPending ? 'PRELIMINARY STATUS' : 'FINAL GRADE / RANK',
              style: const TextStyle(fontSize: 11, letterSpacing: 1.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Text(isPending ? "PENDING REVIEW" : "$score", 
            style: TextStyle(
              fontSize: score.toString().length > 5 ? 32 : 48, 
              fontWeight: FontWeight.w900, 
              color: isPending ? Colors.orange : brandBlue
            )
          ),
          if (!isPending && score is num) 
            Text("out of $total total points", style: const TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: isPending ? null : percent,
            backgroundColor: const Color(0xFFF1F5F9),
            color: isPending ? Colors.orange : brandBlue,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration(bool isPending, Color brandBlue) {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        color: isPending ? const Color(0xFFFFF7ED) : brandBlue.withOpacity(0.1), 
        shape: BoxShape.circle
      ),
      child: Icon(
        isPending ? Icons.hourglass_top_rounded : Icons.workspace_premium_rounded, 
        size: 48, 
        color: isPending ? Colors.orange : brandBlue
      ),
    );
  }

  Widget _buildDetailedList(Map questions, Map answers, Color brandBlue) {
    if (questions.isEmpty) return const Center(child: Text("No question data available."));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("QUESTION BREAKDOWN", 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 1.2)),
        const SizedBox(height: 16),
        ...questions.entries.map((entry) {
          final qId = entry.key;
          final qData = Map<String, dynamic>.from(entry.value as Map);
          final studentAns = Map<String, dynamic>.from((answers[qId] ?? {}) as Map);
          
          final bool isMCQ = qData['type']?.toString().contains('mcq') ?? false;
          final String correctStr = (qData['correctOptions'] as List?)?.join(', ') ?? '';
          final String studentStr = isMCQ 
              ? (studentAns['selected'] as List?)?.join(', ') ?? 'No Answer'
              : studentAns['text'] ?? 'No Answer';
          
          final bool isCorrect = isMCQ && correctStr == studentStr;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LatexText(qData['stem'] ?? '', size: 14),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                _buildResponseRow("YOUR ANSWER", studentStr, isMCQ ? (isCorrect ? Colors.green : Colors.red) : brandBlue),
                if (isMCQ && !isCorrect)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _buildResponseRow("CORRECT", correctStr, Colors.green),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResponseRow(String label, String value, Color color) {
    return Row(
      children: [
        Text("$label: ", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8))),
        Expanded(child: LatexText(value, size: 13, color: color)),
        if (color == Colors.green) const Icon(Icons.check_circle, size: 16, color: Colors.green),
        if (color == Colors.red) const Icon(Icons.cancel, size: 16, color: Colors.red),
      ],
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text("Failed to load results", style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton(onPressed: () => context.go('/'), child: const Text("Go Home")),
        ],
      ),
    );
  }
}
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
  String? _filter; // null = Show All, 'correct', 'incorrect', 'written'

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
      ),
      body: RefreshIndicator(
        color: brandBlue,
        onRefresh: () async { setState(() { _refreshKey = UniqueKey(); _filter = null; }); },
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

            final String status = attempt['status'] ?? 'submitted';
            final bool isPending = status != 'completed'; 
            
            final dynamic score = attempt['score'] ?? attempt['totalPoints'] ?? 0;
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
                    
                    if (!isPending) ...[
                      const SizedBox(height: 24),
                      _buildQuickSummary(questions, answers),
                    ],

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
                      label: 'CLOSE PERFORMANCE VIEW',
                      icon: Icons.close_rounded,
                      color: const Color(0xFF1E293B),
                      onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : context.go('/'),
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
    final Map questions = (results[0].value as Map?) ?? {};
    final Map studentAnswers = Map.from((results[1].value as Map?) ?? {});
    if (studentAnswers.isEmpty && attemptData['answers'] != null) {
      studentAnswers.addAll(Map.from(attemptData['answers']));
    }
    return {'attempt': attemptData, 'questions': questions, 'answers': studentAnswers};
  }

  Widget _buildQuickSummary(Map questions, Map answers) {
    int correctCount = 0;
    int incorrectCount = 0;
    int writtenCount = 0;

    questions.forEach((qId, qValue) {
      final qData = Map<String, dynamic>.from(qValue as Map);
      final String type = qData['type']?.toString() ?? 'mcq_single';
      if (type == 'info_block') return;

      final studentAns = Map<String, dynamic>.from((answers[qId] ?? {}) as Map);
      final bool isMCQ = type.contains('mcq');
      
      if (isMCQ) {
        final List correctOptions = List.from(qData['correctOptions'] ?? []);
        final dynamic selected = studentAns['selected'];
        final bool isThisCorrect = selected is List 
            ? (selected.length == correctOptions.length && selected.every((e) => correctOptions.contains(e)))
            : correctOptions.contains(selected);
        isThisCorrect ? correctCount++ : incorrectCount++;
      } else {
        writtenCount++;
      }
    });

    return Row(
      children: [
        _buildStatTile("CORRECT", correctCount.toString(), Colors.green, 'correct'),
        const SizedBox(width: 12),
        _buildStatTile("WRONG", incorrectCount.toString(), Colors.red, 'incorrect'),
        const SizedBox(width: 12),
        _buildStatTile("WRITTEN", writtenCount.toString(), Colors.blue, 'written'),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, Color color, String type) {
    final bool isActive = _filter == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _filter = isActive ? null : type;
          _showDetails = true; 
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? color : color.withValues(alpha: 0.1), width: 2),
            boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isActive ? Colors.white : color)),
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isActive ? Colors.white70 : color.withValues(alpha: 0.6), letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedList(Map questions, Map answers, Color brandBlue) {
    final entries = questions.entries.where((entry) {
      final qData = Map<String, dynamic>.from(entry.value as Map);
      final String type = qData['type']?.toString() ?? 'mcq_single';
      
      if (type == 'info_block') return _filter == null;
      if (_filter == null) return true;
      
      final studentAns = Map<String, dynamic>.from((answers[entry.key] ?? {}) as Map);
      final bool isMCQ = type.contains('mcq');

      if (_filter == 'written') return !isMCQ;

      final List correctOptions = List.from(qData['correctOptions'] ?? []);
      final dynamic selected = studentAns['selected'];
      final bool isCorrect = isMCQ && (selected is List 
          ? (selected.length == correctOptions.length && selected.every((e) => correctOptions.contains(e)))
          : correctOptions.contains(selected));

      return _filter == 'correct' ? isCorrect : (isMCQ && !isCorrect);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_filter == null ? "FULL BREAKDOWN" : "${_filter!.toUpperCase()} QUESTIONS", 
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 1.2)),
            if (_filter != null)
              GestureDetector(
                onTap: () => setState(() => _filter = null),
                child: const Text("CLEAR FILTER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              )
          ],
        ),
        const SizedBox(height: 16),
        ...entries.map((entry) {
          final qId = entry.key;
          final qData = Map<String, dynamic>.from(entry.value as Map);
          final String type = qData['type']?.toString() ?? 'mcq_single';
          final bool isInfo = type == 'info_block';
          final String? imageUrl = qData['imageUrl'];
          
          final studentAns = Map<String, dynamic>.from((answers[qId] ?? {}) as Map);
          final bool isMCQ = type.contains('mcq');
          final List options = qData['options'] ?? [];
          final List correctOptions = List.from(qData['correctOptions'] ?? []);
          final dynamic selected = studentAns['selected'];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isInfo ? brandBlue.withValues(alpha: 0.02) : Colors.white, 
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isInfo ? brandBlue.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isInfo) const Icon(Icons.info_outline, size: 16, color: Colors.blueGrey),
                    if (isInfo) const SizedBox(width: 8),
                    Expanded(child: LatexText(qData['stem'] ?? '', size: 14)),
                  ],
                ),
                
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(imageUrl, width: double.infinity, fit: BoxFit.contain),
                  ),
                ],

                if (!isInfo) const SizedBox(height: 16),
                
                if (isMCQ) ...[
                  ...options.map((opt) {
                    final String optId = opt is Map ? (opt['id']?.toString() ?? '') : '';
                    final String optText = opt is Map ? (opt['text']?.toString() ?? '') : opt.toString();
                    final bool isThisCorrect = correctOptions.contains(optId);
                    final bool isThisSelected = selected is List ? selected.contains(optId) : selected == optId;
                    
                    Color bgColor = Colors.white;
                    Color borderColor = const Color(0xFFF1F5F9);
                    Widget trailingIcon = const Icon(Icons.radio_button_unchecked_rounded, size: 16, color: Color(0xFFCBD5E1));

                    if (isThisCorrect) {
                      bgColor = Colors.green.withValues(alpha: 0.08);
                      borderColor = Colors.green.shade200;
                      trailingIcon = const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green);
                    } else if (isThisSelected) {
                      bgColor = Colors.red.withValues(alpha: 0.08);
                      borderColor = Colors.red.shade200;
                      trailingIcon = const Icon(Icons.cancel_rounded, size: 18, color: Colors.red);
                    }

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: bgColor, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Text("$optId. ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Expanded(child: LatexText(optText, size: 13)),
                          const SizedBox(width: 8),
                          trailingIcon,
                        ],
                      ),
                    );
                  }),
                ] else if (!isInfo) ...[
                  _buildResponseRow("YOUR RESPONSE", studentAns['text'] ?? 'No Answer', brandBlue),
                  
                  // STUDENT'S UPLOADED IMAGE (ImgBB)
                  if (studentAns['answerImageUrl'] != null) ...[
                    const SizedBox(height: 12),
                    const Text("ATTACHED EVIDENCE:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () => _showFullScreenImage(studentAns['answerImageUrl']),
                        child: Image.network(studentAns['answerImageUrl'], width: double.infinity, height: 160, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, color: Colors.grey)),
                      ),
                    ),
                  ],

                  if (studentAns['manualPoints'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text("Awarded: ${studentAns['manualPoints']} Points", 
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 11)),
                    ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(child: Center(child: Image.network(url))),
            Positioned(top: 40, right: 20, child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)))),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseRow(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          LatexText(value, size: 14, color: color),
        ],
      ),
    );
  }

  Widget _buildScoreCard(dynamic score, num total, bool isPending, Color brandBlue) {
    final double percent = (score is num && total > 0) ? (score / total) : (isPending ? 0.0 : 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Text(isPending ? 'PRELIMINARY STATUS' : 'FINAL GRADE / RANK',
              style: const TextStyle(fontSize: 11, letterSpacing: 1.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Text(isPending ? "PENDING REVIEW" : "$score", 
            style: TextStyle(fontSize: score.toString().length > 5 ? 32 : 48, fontWeight: FontWeight.w900, color: isPending ? Colors.orange : brandBlue)
          ),
          if (!isPending && score is num) 
            Text("out of $total total points", style: const TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          LinearProgressIndicator(value: isPending ? null : percent, backgroundColor: const Color(0xFFF1F5F9), color: isPending ? Colors.orange : brandBlue, borderRadius: BorderRadius.circular(10)),
        ],
      ),
    );
  }

  Widget _buildIllustration(bool isPending, Color brandBlue) {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(color: isPending ? const Color(0xFFFFF7ED) : brandBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(isPending ? Icons.hourglass_top_rounded : Icons.workspace_premium_rounded, size: 48, color: isPending ? Colors.orange : brandBlue),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
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
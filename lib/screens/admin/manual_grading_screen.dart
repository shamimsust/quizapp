import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../widgets/latex_text.dart';

class ManualGradingScreen extends StatefulWidget {
  const ManualGradingScreen({super.key});

  @override
  State<ManualGradingScreen> createState() => _ManualGradingScreenState();
}

class _ManualGradingScreenState extends State<ManualGradingScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final Color _primaryBlue = const Color(0xFF2264D7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F6),
      appBar: AppBar(
        title: const Text('MANUAL GRADING', 
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14)),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: _db.child('attempts').orderByChild('status').equalTo('submitted').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _primaryBlue));
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return _buildEmptyState();
          }

          final Map<dynamic, dynamic> attempts = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
          final attemptList = attempts.entries.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: attemptList.length,
            itemBuilder: (context, index) {
              final String id = attemptList[index].key.toString();
              final attempt = Map<String, dynamic>.from(attemptList[index].value as Map);
              final candidate = attempt['candidate'] ?? {};

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                    child: Icon(Icons.person_search_outlined, color: _primaryBlue),
                  ),
                  title: Text(candidate['name'] ?? 'Anonymous Student', 
                      style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Inter', color: Color(0xFF1E293B))),
                  subtitle: Text('Exam: ${attempt['examTitle'] ?? 'Unknown'}\nEmail: ${candidate['email'] ?? 'N/A'}', 
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openGradingModal(id, attempt),
                    child: const Text('Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openGradingModal(String attemptId, Map<String, dynamic> attempt) async {
    final String candidateName = attempt['candidate']?['name'] ?? 'Student';
    final String examId = attempt['examId'] ?? '';
    final scoreController = TextEditingController(text: attempt['score']?.toString() ?? '');
    
    // Show Loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final results = await Future.wait([
      _db.child('exams/$examId/questions').get(),
      _db.child('attemptAnswers/$attemptId').get(),
    ]);
    
    if (mounted) Navigator.pop(context); // Close loading dialog

    final Map<dynamic, dynamic> originalQuestions = (results[0].value as Map?) ?? {};
    final Map<dynamic, dynamic> studentAnswers = (results[1].value as Map?) ?? {};

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20, right: 20, top: 20
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Grading: $candidateName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (studentAnswers.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No detailed answers found."))),

                    ...studentAnswers.entries.map((entry) {
                      final String qId = entry.key.toString();
                      final studentData = Map<String, dynamic>.from(entry.value as Map);
                      final questionObj = originalQuestions[qId];
                      
                      final String originalStem = questionObj != null ? (questionObj['stem'] ?? "No stem text") : "Missing Question";
                      final String studentResponse = studentData['text'] ?? (studentData['selected']?.toString() ?? "N/A");

                      return _buildAnswerCard(originalStem, studentResponse, studentData['type'] ?? 'written');
                    }),

                    const SizedBox(height: 20),
                    const Text('FINAL RANKING / SCORE', 
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: scoreController,
                      decoration: InputDecoration(
                        hintText: 'e.g. 1st, 2nd or points...',
                        helperText: 'Using Rank Option as per BP requirements',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => _submitFinalGrade(attemptId, scoreController.text.trim()),
                        child: const Text('COMPLETE GRADING', 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: Captured context-dependent objects before the async gap
  Future<void> _submitFinalGrade(String attemptId, String score) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await _db.child('attempts/$attemptId').update({
        'status': 'completed',
        'score': score,
        'gradedAt': ServerValue.timestamp,
        'isManualGraded': true,
      });

      messenger.showSnackBar(const SnackBar(content: Text('Grading finalized successfully!'), backgroundColor: Colors.green));
      navigator.pop(); // Close BottomSheet
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Widget _buildAnswerCard(String stem, String response, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(type.toUpperCase(), 
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _primaryBlue)),
          ),
          const SizedBox(height: 12),
          LatexText(stem, size: 14),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          const Text('STUDENT RESPONSE:', 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC), 
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _primaryBlue.withValues(alpha: 0.05)),
            ),
            child: LatexText(response, size: 15, color: const Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rtl_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          const Text("Inbox Zero!", style: TextStyle(fontSize: 18, color: Color(0xFF64748B), fontWeight: FontWeight.w800, fontFamily: 'Inter')),
          const Text("All pending submissions have been graded.", style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}
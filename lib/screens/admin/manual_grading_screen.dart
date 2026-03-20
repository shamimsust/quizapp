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
        title: const Text('Manual Grading', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder(
        // Listening for all submitted attempts
        stream: _db.child('attempts').orderByChild('status').equalTo('submitted').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _primaryBlue.withOpacity(0.1),
                    child: Icon(Icons.person_search_outlined, color: _primaryBlue),
                  ),
                  title: Text(candidate['name'] ?? 'Anonymous Student', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                  subtitle: Text('Exam: ${attempt['examTitle'] ?? 'Unknown'}\nEmail: ${candidate['email'] ?? 'N/A'}', 
                      style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _openGradingModal(id, attempt),
                    child: const Text('Review', style: TextStyle(color: Colors.white)),
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
    
    // Pre-fill score if one exists (e.g. from auto-grading)
    final scoreController = TextEditingController(text: attempt['score']?.toString() ?? '');
    
    // Show Loading while fetching details
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    // Fetch original questions and student's specific answers
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
                Text('Grading: $candidateName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (studentAnswers.isEmpty)
                      const Padding(padding: EdgeInsets.all(40), child: Text("No detailed answers found.")),

                    ...studentAnswers.entries.map((entry) {
                      final String qId = entry.key.toString();
                      final studentData = Map<String, dynamic>.from(entry.value as Map);
                      final questionObj = originalQuestions[qId];
                      
                      final String originalStem = questionObj != null ? (questionObj['stem'] ?? "No stem text") : "Missing Question";
                      final String studentResponse = studentData['text'] ?? (studentData['selected']?.toString() ?? "N/A");

                      return _buildAnswerCard(originalStem, studentResponse, studentData['type'] ?? 'written');
                    }).toList(),

                    const SizedBox(height: 20),
                    const Align(alignment: Alignment.centerLeft, child: Text('Final Rank / Score', style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: scoreController,
                      decoration: InputDecoration(
                        hintText: 'Enter Rank (e.g., 1st) or Points',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () async {
                          await _db.child('attempts/$attemptId').update({
                            'status': 'completed',
                            'score': scoreController.text.trim(),
                            'gradedAt': ServerValue.timestamp,
                            'isManualGraded': true,
                          });
                          if (mounted) Navigator.pop(context);
                        },
                        child: const Text('Complete Grading', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildAnswerCard(String stem, String response, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryBlue)),
            ],
          ),
          const SizedBox(height: 10),
          LatexText(stem, size: 14),
          const Divider(height: 30),
          const Text('STUDENT RESPONSE:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(8)),
            child: LatexText(response, size: 15, color: _primaryBlue),
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
          Icon(Icons.done_all_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No pending submissions!", style: TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
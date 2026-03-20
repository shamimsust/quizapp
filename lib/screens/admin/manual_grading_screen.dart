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
        stream: _db.child('attempts').orderByChild('status').equalTo('submitted').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fact_check_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('All Caught Up!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const Text('No submissions waiting for grading.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final Map<dynamic, dynamic> attempts = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: attempts.length,
            itemBuilder: (context, index) {
              final String id = attempts.keys.elementAt(index);
              final attempt = Map<String, dynamic>.from(attempts[id]);
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
                  subtitle: Text('ID: $id\nEmail: ${candidate['email'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      elevation: 0,
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
    final scoreController = TextEditingController();
    
    // Fetch original questions and student answers
    final List<Future<DataSnapshot>> futures = [
      _db.child('exams/$examId/questions').get(),
      _db.child('attemptAnswers/$attemptId').get(),
    ];
    
    final results = await Future.wait(futures);
    final Map<dynamic, dynamic> originalQuestions = (results[0].value as Map?) ?? {};
    final Map<dynamic, dynamic> studentAnswers = (results[1].value as Map?) ?? {};

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85, // Take up 85% of screen
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24, right: 24, top: 24
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Grading: $candidateName', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                    overflow: TextOverflow.ellipsis),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    if (studentAnswers.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text("No answers recorded for this attempt."),
                      )),

                    ...studentAnswers.entries.toList().asMap().entries.map((entry) {
                      final int serial = entry.key + 1;
                      final String qId = entry.value.key.toString();
                      final studentData = Map<String, dynamic>.from(entry.value.value as Map);
                      
                      final questionObj = originalQuestions[qId];
                      String originalText;
                      if (questionObj != null) {
                        originalText = (questionObj['stem'] ?? questionObj['text'] ?? "Question content missing.");
                      } else {
                        originalText = "Question ID Mismatch: $qId";
                      }

                      final String responseText = studentData['text'] ?? (studentData['selected']?.toString() ?? "N/A");

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('QUESTION $serial', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: _primaryBlue, letterSpacing: 1.1)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: Text(studentData['type']?.toString().toUpperCase() ?? 'WRITTEN', 
                                      style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // ORIGINAL QUESTION (Mixed Mode)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: LatexText(originalText, size: 14),
                            ),
                            
                            const SizedBox(height: 16),
                            const Text('STUDENT RESPONSE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
                            const SizedBox(height: 8),
                            
                            // STUDENT RESPONSE (Mixed Mode)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: _primaryBlue.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: LatexText(responseText, size: 15, color: _primaryBlue),
                            ),
                          ],
                        ),
                      );
                    }),

                    const Text('Final Evaluation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: scoreController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: 'Final Rank / Score',
                        hintText: 'e.g. 1st, 2nd or points',
                        prefixIcon: const Icon(Icons.emoji_events_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final String finalGrade = scoreController.text.trim();
                          if (finalGrade.isEmpty) return;
                          
                          await _db.child('attempts/$attemptId').update({
                            'status': 'completed',
                            'score': finalGrade,
                            'gradedAt': ServerValue.timestamp,
                            'isManualGraded': true,
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Grade saved successfully!'), backgroundColor: Colors.green),
                            );
                          }
                        },
                        child: const Text('Confirm & Save Grade', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
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
  
  final TextEditingController _examSearchController = TextEditingController();
  final ValueNotifier<String> _examSearchQuery = ValueNotifier<String>('');

  String? _selectedExamId;
  String? _selectedExamTitle;

  @override
  void dispose() {
    _examSearchController.dispose();
    _examSearchQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isViewingStudents = _selectedExamId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F6),
      appBar: AppBar(
        title: Text(isViewingStudents ? _selectedExamTitle!.toUpperCase() : 'SELECT EXAM', 
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14)),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: isViewingStudents 
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded), 
              onPressed: () => setState(() => _selectedExamId = null))
          : null,
      ),
      body: isViewingStudents ? _buildStudentList() : _buildExamSelectionUI(),
    );
  }

  Widget _buildExamSelectionUI() {
    return Column(
      children: [
        Container(
          color: _primaryBlue,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: TextField(
            controller: _examSearchController,
            onChanged: (val) => _examSearchQuery.value = val.toLowerCase(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search exams...',
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha:0.15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: _examSearchQuery,
            builder: (context, query, _) => _buildExamList(query),
          ),
        ),
      ],
    );
  }

  Widget _buildExamList(String query) {
    return StreamBuilder(
      stream: _db.child('attempts').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: Text("No submissions found."));
        }
        final Map allAttempts = Map.from(snapshot.data!.snapshot.value as Map);
        final Map<String, Map<String, dynamic>> examGroups = {};
        allAttempts.forEach((id, data) {
          final attempt = Map<String, dynamic>.from(data as Map);
          final String eId = attempt['examId'] ?? 'unknown';
          final String eTitle = attempt['examTitle'] ?? 'Untitled';
          if (query.isEmpty || eTitle.toLowerCase().contains(query)) {
            if (!examGroups.containsKey(eId)) examGroups[eId] = {'title': eTitle, 'pending': 0, 'completed': 0};
            attempt['status'] == 'submitted' ? examGroups[eId]!['pending']++ : examGroups[eId]!['completed']++;
          }
        });
        final examList = examGroups.entries.toList();
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: examList.length,
          itemBuilder: (context, index) {
            final stats = examList[index].value;
            return Card(
              elevation: 0, margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                onTap: () => setState(() { _selectedExamId = examList[index].key; _selectedExamTitle = stats['title']; }),
                title: Text(stats['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${stats['completed']} Graded • ${stats['pending']} Pending"),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentList() {
    return StreamBuilder(
      stream: _db.child('attempts').orderByChild('examId').equalTo(_selectedExamId).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) return const Center(child: Text("No scripts found."));
        final Map attempts = Map.from(snapshot.data!.snapshot.value as Map);
        final list = attempts.entries.toList();
        final pending = list.where((e) => (e.value as Map)['status'] == 'submitted').toList();
        final completed = list.where((e) => (e.value as Map)['status'] == 'completed').toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (pending.isNotEmpty) ...[
              const Text("SCRIPTS TO GRADE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 1.2)),
              const SizedBox(height: 12),
              ...pending.map((e) => _buildStudentCard(e.key.toString(), Map.from(e.value as Map), false)),
            ],
            const SizedBox(height: 24),
            if (completed.isNotEmpty) ...[
              const Text("FINALIZED RESULTS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 1.2)),
              const SizedBox(height: 12),
              ...completed.map((e) => _buildStudentCard(e.key.toString(), Map.from(e.value as Map), true)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStudentCard(String id, Map<String, dynamic> attempt, bool isDone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(attempt['candidate']?['name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(isDone ? "Final Score: ${attempt['score']}" : "Ready for evaluation", style: TextStyle(fontSize: 12, color: isDone ? _primaryBlue : const Color(0xFF64748B))),
            ]),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDone ? Colors.white : _primaryBlue, foregroundColor: isDone ? _primaryBlue : Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => _openGradingModal(id, attempt, isDone),
            child: Text(isDone ? 'Edit' : 'Grade'),
          ),
        ],
      ),
    );
  }

  void _openGradingModal(String attemptId, Map<String, dynamic> attempt, bool isDone) async {
    final String candidateName = attempt['candidate']?['name'] ?? 'Student';
    final String examId = attempt['examId'] ?? '';
    final remarkController = TextEditingController(text: attempt['remarks'] ?? '');
    
    final Map<String, TextEditingController> scoreControllers = {};

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final results = await Future.wait([
      _db.child('exams/$examId/questions').get(),
      _db.child('attemptAnswers/$attemptId').get(),
    ]);
    if (!mounted) return;
    Navigator.pop(context);

    final Map originalQuestions = (results[0].value as Map?) ?? {};
    final Map studentAnswers = (results[1].value as Map?) ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 20, right: 20, top: 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(candidateName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Max Possible: ${attempt['totalPossible'] ?? '?'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...studentAnswers.entries.where((e) {
                        final q = originalQuestions[e.key.toString()];
                        return q != null && q['type'] != 'info_block';
                    }).map((entry) {
                      final qId = entry.key.toString();
                      final studentData = Map<String, dynamic>.from(entry.value as Map);
                      final questionObj = originalQuestions[qId];
                      
                      // Initialize controller
                      scoreControllers[qId] = TextEditingController(
                        text: (studentData['manualPoints'] ?? studentData['autoPoints'] ?? '0').toString()
                      );

                      return _buildAnswerGradingCard(
                        stem: questionObj?['stem'] ?? "Question missing", 
                        questionImageUrl: questionObj?['imageUrl'],
                        answerImageUrl: studentData['answerImageUrl'], // Added for student uploads
                        response: studentData['text'] ?? (studentData['selected']?.toString() ?? "N/A"), 
                        type: studentData['type'] ?? 'written',
                        controller: scoreControllers[qId]!,
                      );
                    }),
                    const SizedBox(height: 20),
                    _buildInputField('OVERALL FEEDBACK', remarkController, false),
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, height: 56, 
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () => _submitPerQuestionGrade(attemptId, remarkController.text.trim(), scoreControllers),
                        child: const Text('SAVE PER-QUESTION GRADES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerGradingCard({
    required String stem, 
    String? questionImageUrl,
    String? answerImageUrl,
    required String response, 
    required String type, 
    required TextEditingController controller
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(type.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _primaryBlue, letterSpacing: 1)),
        const SizedBox(height: 8),
        LatexText(stem, size: 14),
        
        // Question Image (Teacher's prompt)
        if (questionImageUrl != null && questionImageUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(questionImageUrl, width: double.infinity, fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, color: Colors.grey)),
          ),
        ],

        const Divider(height: 24),
        const Text("STUDENT RESPONSE:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12), 
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)), 
          child: LatexText(response, size: 15)
        ),

        // Student's Uploaded Image (Evidence/Diagram)
        if (answerImageUrl != null && answerImageUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text("ATTACHED EVIDENCE:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () => _showFullScreenImage(answerImageUrl),
              child: Image.network(answerImageUrl, width: double.infinity, fit: BoxFit.cover, height: 200,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, color: Colors.grey)),
            ),
          ),
        ],

        const SizedBox(height: 16),
        Row(
          children: [
            const Text("ASSIGN MARKS:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              height: 40,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true, fillColor: _primaryBlue.withValues(alpha:0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primaryBlue.withValues(alpha:0.2))),
                ),
              ),
            ),
          ],
        ),
      ]),
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

  Widget _buildInputField(String label, TextEditingController controller, bool isNumber) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.2)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        maxLines: isNumber ? 1 : 3,
        keyboardType: isNumber ? TextInputType.number : TextInputType.multiline,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
          filled: true, fillColor: const Color(0xFFF8FAFC),
        ),
      ),
    ]);
  }

  Future<void> _submitPerQuestionGrade(String attemptId, String feedback, Map<String, TextEditingController> scoreControllers) async {
    double totalCalculatedScore = 0;
    final Map<String, dynamic> updates = {};

    scoreControllers.forEach((qId, controller) {
      final double qScore = double.tryParse(controller.text) ?? 0;
      totalCalculatedScore += qScore;
      updates['attemptAnswers/$attemptId/$qId/manualPoints'] = qScore;
    });

    updates['attempts/$attemptId/status'] = 'completed';
    updates['attempts/$attemptId/remarks'] = feedback;
    updates['attempts/$attemptId/score'] = totalCalculatedScore;
    updates['attempts/$attemptId/totalPoints'] = totalCalculatedScore;
    updates['attempts/$attemptId/isManualGraded'] = true;
    updates['attempts/$attemptId/gradedAt'] = ServerValue.timestamp;

    await _db.update(updates);
    if (mounted) Navigator.pop(context);
  }
}
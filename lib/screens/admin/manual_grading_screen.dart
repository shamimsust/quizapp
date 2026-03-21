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
    bool isViewingStudents = _selectedExamId != null;

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
              onPressed: () {
                setState(() => _selectedExamId = null);
                _examSearchQuery.value = '';
                _examSearchController.clear();
              })
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
              hintText: 'Search exams by title...',
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
          return const Center(child: Text("No exam submissions found."));
        }

        final Map<dynamic, dynamic> allAttempts = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
        Map<String, Map<String, dynamic>> examGroups = {};

        allAttempts.forEach((id, data) {
          final attempt = Map<String, dynamic>.from(data as Map);
          final String eId = attempt['examId'] ?? 'unknown';
          final String eTitle = attempt['examTitle'] ?? 'Untitled Exam';

          if (query.isEmpty || eTitle.toLowerCase().contains(query)) {
            if (!examGroups.containsKey(eId)) {
              examGroups[eId] = {'title': eTitle, 'pending': 0, 'completed': 0};
            }
            if (attempt['status'] == 'submitted') {
              examGroups[eId]!['pending']++;
            } else if (attempt['status'] == 'completed') {
              examGroups[eId]!['completed']++;
            }
          }
        });

        if (examGroups.isEmpty) return const Center(child: Text("No matching exams."));
        final examList = examGroups.entries.toList();

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: examList.length,
          itemBuilder: (context, index) {
            final stats = examList[index].value;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                onTap: () => setState(() {
                  _selectedExamId = examList[index].key;
                  _selectedExamTitle = stats['title'];
                }),
                title: Text(stats['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${stats['completed']} Graded • ${stats['pending']} Pending", 
                  style: TextStyle(color: stats['pending'] > 0 ? Colors.orange.shade800 : Colors.grey)),
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
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: Text("No student scripts found for this exam."));
        }

        final Map<dynamic, dynamic> attempts = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final list = attempts.entries.toList();
        final pending = list.where((e) => (e.value as Map)['status'] == 'submitted').toList();
        final completed = list.where((e) => (e.value as Map)['status'] == 'completed').toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (pending.isNotEmpty) ...[
              const Text("SCRIPTS TO GRADE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 1.2)),
              const SizedBox(height: 12),
              ...pending.map((e) => _buildStudentCard(e.key.toString(), Map<String, dynamic>.from(e.value as Map), false)),
            ],
            const SizedBox(height: 24),
            if (completed.isNotEmpty) ...[
              const Text("FINALIZED RESULTS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 1.2)),
              const SizedBox(height: 12),
              ...completed.map((e) => _buildStudentCard(e.key.toString(), Map<String, dynamic>.from(e.value as Map), true)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attempt['candidate']?['name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(isDone ? "Final Score: ${attempt['totalPoints']}" : "Ready for evaluation", 
                  style: TextStyle(fontSize: 12, color: isDone ? _primaryBlue : const Color(0xFF64748B))),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDone ? Colors.white : _primaryBlue,
              foregroundColor: isDone ? _primaryBlue : Colors.white,
              elevation: 0,
              side: isDone ? BorderSide(color: _primaryBlue) : BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
    final scoreController = TextEditingController(text: (attempt['totalPoints'] ?? '').toString());
    final feedbackController = TextEditingController(text: attempt['score']?.toString() ?? '');
    
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final results = await Future.wait([
      _db.child('exams/$examId/questions').get(),
      _db.child('attemptAnswers/$attemptId').get(),
    ]);
    if (mounted) Navigator.pop(context);

    final Map<dynamic, dynamic> originalQuestions = (results[0].value as Map?) ?? {};
    final Map<dynamic, dynamic> studentAnswers = (results[1].value as Map?) ?? {};

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
                Text(candidateName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...studentAnswers.entries.map((entry) {
                      final studentData = Map<String, dynamic>.from(entry.value as Map);
                      final questionObj = originalQuestions[entry.key.toString()];
                      return _buildAnswerCard(questionObj?['stem'] ?? "Question missing", 
                        studentData['text'] ?? (studentData['selected']?.toString() ?? "N/A"), studentData['type'] ?? 'written');
                    }),
                    const SizedBox(height: 20),
                    _buildInputField('TOTAL SCORE', scoreController, true),
                    const SizedBox(height: 16),
                    _buildInputField('FEEDBACK / REMARKS', feedbackController, false),
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, height: 56, 
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () => _submitFinalGrade(attemptId, feedbackController.text.trim(), scoreController.text.trim()),
                        child: const Text('SUBMIT FINAL GRADE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      )),
                    if (isDone) 
                      TextButton.icon(
                        icon: const Icon(Icons.undo_rounded, color: Colors.redAccent),
                        label: const Text('RESET TO UNGRADED', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        onPressed: () => _resetToPending(attemptId),
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

  Widget _buildInputField(String label, TextEditingController controller, bool isNumber) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.2)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: const Color(0xFFF8FAFC)),
      ),
    ]);
  }

  Future<void> _submitFinalGrade(String attemptId, String feedback, String points) async {
    await _db.child('attempts/$attemptId').update({
      'status': 'completed', 'score': feedback, 'totalPoints': points,
      'gradedAt': ServerValue.timestamp, 'isManualGraded': true
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _resetToPending(String attemptId) async {
    await _db.child('attempts/$attemptId').update({
      'status': 'submitted', 'score': null, 'totalPoints': null, 'isManualGraded': false, 'gradedAt': null,
    });
    if (mounted) Navigator.pop(context);
  }

  Widget _buildAnswerCard(String stem, String response, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(type == 'mcq' ? 'MULTIPLE CHOICE' : 'WRITTEN ANSWER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _primaryBlue)),
        const SizedBox(height: 8),
        LatexText(stem, size: 14),
        const Divider(height: 24),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)), child: LatexText(response, size: 15)),
      ]),
    );
  }
}
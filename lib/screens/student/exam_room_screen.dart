import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; 
import '../../widgets/latex_text.dart'; 

class ExamRoomScreen extends StatefulWidget {
  final String attemptId;
  const ExamRoomScreen({super.key, required this.attemptId});

  @override
  State<ExamRoomScreen> createState() => _ExamRoomScreenState();
}

class _ExamRoomScreenState extends State<ExamRoomScreen> {
  final _db = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? attempt;
  List<Map<String, dynamic>> questions = [];
  
  // Track selections and written text controllers
  final Map<String, List<String>> _selected = {};
  final Map<String, TextEditingController> _controllers = {};
  
  bool _submitting = false;
  String? _error;

  // Connection and Sync Tracking
  bool _isConnected = true;
  DateTime? _lastSynced;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _setupConnectionListener();
  }

  void _setupConnectionListener() {
    _connectionSubscription = _db.child(".info/connected").onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (mounted) {
        setState(() => _isConnected = connected);
      }
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final attSnap = await _db.child('attempts/${widget.attemptId}').get();
      if (!attSnap.exists) throw Exception("Attempt not found.");
      
      final attData = Map<String, dynamic>.from(attSnap.value as Map);
      final examId = attData['examId'];

      // Load questions
      final qSnap = await _db.child('exams/$examId/questions').get();
      final List<Map<String, dynamic>> loadedQuestions = [];
      
      if (qSnap.exists) {
        final rawData = qSnap.value;
        if (rawData is Map) {
          rawData.forEach((key, value) {
            loadedQuestions.add({
              'id': key.toString(), 
              ...Map<String, dynamic>.from(value as Map)
            });
          });
        }
      }

      // Load existing progress from database
      final ansSnap = await _db.child('attemptAnswers/${widget.attemptId}').get();
      if (ansSnap.exists) {
        final existing = Map<dynamic, dynamic>.from(ansSnap.value as Map);
        existing.forEach((qid, data) {
          if (data['selected'] != null) {
            _selected[qid] = List<String>.from(data['selected']);
          }
          if (data['text'] != null) {
             _controllers[qid] = TextEditingController(text: data['text']);
          }
        });
      }

      if (mounted) {
        setState(() {
          attempt = attData;
          questions = loadedQuestions;
          _lastSynced = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _updateSyncStatus() {
    if (mounted) {
      setState(() => _lastSynced = DateTime.now());
    }
  }

  // --- INPUT HANDLERS ---

  void _handleOptionTap(String qid, String optId, String type) async {
    final current = List<String>.from(_selected[qid] ?? <String>[]);
    
    if (type == 'mcq_single' || type == 'mcq') {
       current.clear();
       current.add(optId);
    } else {
      current.contains(optId) ? current.remove(optId) : current.add(optId);
    }

    setState(() => _selected[qid] = current);
    
    // Auto-save to Firebase
    await _db.child('attemptAnswers/${widget.attemptId}/$qid').update({
      'type': type,
      'selected': current,
      'savedAt': ServerValue.timestamp,
    });
    _updateSyncStatus();
  }

  void _handleWrittenChange(String qid, String text) {
    _db.child('attemptAnswers/${widget.attemptId}/$qid').update({
      'type': 'written',
      'text': text,
      'savedAt': ServerValue.timestamp,
    });
    _updateSyncStatus();
  }

  // --- UPDATED SUBMISSION LOGIC ---

  Future<void> _submit() async {
    if (_submitting || !mounted) return;
    setState(() => _submitting = true);

    try {
      // 1. Fetch Exam Metadata to check for global Manual Grading preference
      final examId = attempt?['examId'];
      final examSnap = await _db.child('exams/$examId').get();
      final examMeta = examSnap.exists ? Map<String, dynamic>.from(examSnap.value as Map) : {};
      
      final bool forceManual = examMeta['isManualGrading'] ?? false;
      int totalPossible = 0;
      num obtainedScore = 0; 
      bool hasWrittenContent = false;

      final ansSnap = await _db.child('attemptAnswers/${widget.attemptId}').get();
      final userAnswers = (ansSnap.value as Map?) ?? {};

      // 2. Loop through questions for scoring
      for (var q in questions) {
        final qid = q['id'];
        final type = q['type'] ?? 'mcq_single';
        final int qMarks = q['marks'] ?? 1;
        totalPossible += qMarks;

        if (type == 'written') {
          hasWrittenContent = true; 
        } else {
          final List correct = q['correctOptions'] ?? [];
          final userEntry = userAnswers[qid];
          final List selected = (userEntry != null) ? (userEntry['selected'] ?? []) : [];

          final bool isCorrect = selected.length == correct.length &&
              selected.every((e) => correct.contains(e));

          if (isCorrect) obtainedScore += qMarks;
        }
      }

      // 3. Determine status: If Force Manual (BP Ranks) or Written exists, set to 'submitted'
      final bool needsReview = forceManual || hasWrittenContent;
      final finalStatus = needsReview ? 'submitted' : 'completed';

      await _db.child('attempts/${widget.attemptId}').update({
        'status': finalStatus,
        'score': obtainedScore,
        'totalPossible': totalPossible,
        'isManualGraded': needsReview,
        'submittedAt': ServerValue.timestamp,
        'examTitle': examMeta['title'] ?? 'Quiz',
      });
      
      if (mounted) context.go('/submitted/${widget.attemptId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submit failed: $e")));
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _confirmAndSubmit() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Submission', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to end the quiz? Your answers will be submitted for grading.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('BACK', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2264D7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('SUBMIT NOW', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
    if (confirm == true) _submit();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(body: Center(child: Text("Error: $_error")));
    if (attempt == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final endTime = attempt!['endTime'] as int? ?? 0;
    const Color brandBlue = Color(0xFF2264D7);
    final String syncTime = _lastSynced != null ? DateFormat('HH:mm:ss').format(_lastSynced!) : "--:--";

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Live Quiz', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _isConnected ? Colors.greenAccent : Colors.orangeAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(_isConnected ? "Synced" : "Offline", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text("Last: $syncTime", style: TextStyle(fontSize: 9, color: Colors.white.withAlpha(204))),
              ],
            ),
          ),
          IconButton(onPressed: _submitting ? null : _confirmAndSubmit, icon: const Icon(Icons.send_rounded)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
            child: Center(
              child: (endTime > 0) 
                  ? ExamTimer(endTimeMs: endTime, onTimeUp: _submit)
                  : const Text("No Time Limit"),
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final q = questions[index];
                final qid = q['id'];
                final type = q['type'] ?? 'mcq_single';
                final stem = q['stem'] ?? q['text'] ?? "Question text missing";

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${index + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Expanded(child: LatexText(stem, size: 16)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        if (type == 'written')
                          TextField(
                            controller: _controllers.putIfAbsent(qid, () => TextEditingController()),
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: 'Type your answer here (LaTeX supported)...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              fillColor: Colors.grey.shade50,
                              filled: true,
                            ),
                            onChanged: (val) => _handleWrittenChange(qid, val),
                          )
                        else if (q['options'] != null)
                          ... (q['options'] as List).map((opt) {
                            final optId = opt['id'].toString();
                            final optText = opt['text'] ?? "";
                            final isSelected = (_selected[qid] ?? []).contains(optId);

                            return GestureDetector(
                              onTap: () => _handleOptionTap(qid, optId, type),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected ? brandBlue.withAlpha(13) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isSelected ? brandBlue : Colors.grey.shade300, width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Icon(isSelected ? Icons.check_circle : Icons.radio_button_off, color: isSelected ? brandBlue : Colors.grey, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(child: LatexText(optText, size: 15)),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- TIMER WIDGET ---

class ExamTimer extends StatefulWidget {
  final int endTimeMs;
  final VoidCallback onTimeUp;
  const ExamTimer({super.key, required this.endTimeMs, required this.onTimeUp});

  @override
  State<ExamTimer> createState() => _ExamTimerState();
}

class _ExamTimerState extends State<ExamTimer> {
  Timer? _timer;
  int remaining = 0;
  bool _warned = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = widget.endTimeMs - now;
    
    if (mounted) {
      setState(() => remaining = diff.clamp(0, 999999999));
    }
    
    if (diff <= 60000 && diff > 0 && !_warned) {
      _warned = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _showWarning(); });
    }

    if (diff <= 0) {
      _timer?.cancel();
      widget.onTimeUp();
    }
  }

  void _showWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Time is almost up!')]),
        content: const Text('You have 1 minute left. The quiz will auto-submit when the timer reaches zero.'),
        actions: [
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2264D7)), onPressed: () => Navigator.pop(context), child: const Text('GOT IT', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = Duration(milliseconds: remaining);
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours.toString().padLeft(2, '0');
    final bool isUrgent = remaining < 300000; 

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.shade50 : const Color(0xFF2264D7).withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isUrgent ? Colors.red : const Color(0xFF2264D7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: isUrgent ? Colors.red : const Color(0xFF2264D7)),
          const SizedBox(width: 8),
          Text('$hh:$mm:$ss', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: isUrgent ? Colors.red : const Color(0xFF2264D7), fontSize: 16)),
        ],
      ),
    );
  }
}
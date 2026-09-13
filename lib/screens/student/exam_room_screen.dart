import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform; // Added for platform checks
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb; // Added for web check
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart'; // Added security plugin
import '../../models/question.dart';
import '../../services/exam_service.dart';
import '../../widgets/latex_text.dart';

class ExamRoomScreen extends StatefulWidget {
  final String attemptId;
  const ExamRoomScreen({super.key, required this.attemptId});

  @override
  State<ExamRoomScreen> createState() => _ExamRoomScreenState();
}

class _ExamRoomScreenState extends State<ExamRoomScreen> with WidgetsBindingObserver {
  final _db = FirebaseDatabase.instance.ref();
  final _examService = ExamService();
  final String _imgBBKey = "bd9c2f7a1ff71a3e72aead970348d485";

  Map<String, dynamic>? attempt;
  List<Question> questions = [];
  bool _allowStudentUpload = false;
  String _examTitle = 'Quiz';

  final Map<String, List<String>> _selected = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _writtenImages = {};
  final Map<String, bool> _uploadingStates = {};

  bool _submitting = false;
  String? _error;

  bool _isConnected = true;
  DateTime? _lastSynced;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;

  // --- ANTI-CHEAT CONFIGURATION ---
  int _tabSwitchStrikes = 0;
  final int _maxAllowedSwitches = 3;
  // Suppresses tab-switch detection while the app itself causes a lifecycle
  // change (e.g. opening the system image picker, camera, or a permission
  // dialog). Without this, legitimate actions like attaching an image get
  // misreported as cheating because they also trigger `inactive`/`paused`.
  bool _expectingSystemUI = false;

  @override
  void initState() {
    super.initState();
    _enableSecurity(); // Initialize screen protection
    WidgetsBinding.instance.addObserver(this);
    _load();
    _setupConnectionListener();
  }

  // Prevents screenshots, screen recording, and "Circle to Search" on Android
  Future<void> _enableSecurity() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } catch (e) {
        debugPrint("Security flags failed: $e");
      }
    }
  }

  // Disable protection when leaving the screen
  Future<void> _disableSecurity() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      } catch (e) {
        debugPrint("Security clear failed: $e");
      }
    }
  }

  @override
  void dispose() {
    _disableSecurity(); // Important: cleanup security flags
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Detects app minimizing, split screen, or recent apps view
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Ignore lifecycle changes we caused ourselves (e.g. image picker,
      // camera, permission dialogs) so legitimate actions aren't flagged.
      if (_expectingSystemUI) return;
      _handleTabSwitch();
    }
  }

  // Wrap any action that is expected to spawn system UI (image picker,
  // camera, share sheet, permission prompts, etc.) so the resulting
  // inactive/paused lifecycle event isn't counted as a tab switch.
  // try/finally guarantees the flag is cleared even if the action throws.
  Future<T?> _runWithSystemUIException<T>(Future<T?> Function() action) async {
    _expectingSystemUI = true;
    try {
      return await action();
    } finally {
      _expectingSystemUI = false;
    }
  }

  void _handleTabSwitch() {
    if (_submitting) return;

    setState(() => _tabSwitchStrikes++);

    _db.child('attempts/${widget.attemptId}/cheatingLogs').push().set({
      'type': 'tab_switch',
      'timestamp': ServerValue.timestamp,
      'strikeNumber': _tabSwitchStrikes,
    });

    if (_tabSwitchStrikes >= _maxAllowedSwitches) {
      _forceSubmitDueToCheating();
    } else {
      _showCheatingWarning();
    }
  }

  void _forceSubmitDueToCheating() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Maximum tab switches exceeded. Submitting automatically."),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );

    // Submit first; _submit() itself navigates to the "submitted" screen
    // once it's done, so we avoid popping this screen and then trying to
    // use its (possibly disposed) context/navigator afterwards.
    _submit();
  }

  void _showCheatingWarning() {
    final int remaining = _maxAllowedSwitches - _tabSwitchStrikes;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Prohibited Action'),
          ],
        ),
        content: Text(
          'Switching apps or screenshots are not allowed.\n\n'
          'Strikes: $_tabSwitchStrikes / $_maxAllowedSwitches\n'
          'Remaining chances: $remaining\n\n'
          'Exceeding this will submit your exam automatically.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2264D7)),
            onPressed: () => Navigator.pop(context),
            child: const Text('I UNDERSTAND', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _setupConnectionListener() {
    _connectionSubscription =
        _db.child(".info/connected").onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (mounted) {
        setState(() => _isConnected = connected);
      }
    });
  }

  Future<void> _load() async {
    try {
      final attSnap = await _db.child('attempts/${widget.attemptId}').get();
      if (!attSnap.exists) throw Exception("Attempt not found.");

      final attData = Map<String, dynamic>.from(attSnap.value as Map);
      final examId = attData['examId'];

      // Exam-level config (title, shuffle flags, upload permission) isn't
      // sensitive on its own, so it's fine to read directly here.
      final examSnap = await _db.child('exams/$examId').get();
      final examMeta = examSnap.exists
          ? Map<String, dynamic>.from(examSnap.value as Map)
          : <String, dynamic>{};

      final bool shuffleQ = examMeta['shuffleQuestions'] ?? false;
      final bool shuffleOpt = examMeta['shuffleOptions'] ?? false;
      final bool allowUpload = examMeta['allowStudentUpload'] ?? false;
      final String examTitle = examMeta['title'] ?? 'Quiz';

      // Questions are fetched through the secure, student-facing path.
      // Question.forStudent() never populates correctOptions, so the
      // answer key doesn't get modeled into the app at all here.
      // NOTE: this only protects the in-app model — see the security
      // note about moving correctOptions to a server-only DB node if you
      // want the raw network payload to be answer-key-free too.
      List<Question> loadedQuestions =
          await _examService.watchQuestionsForStudent(examId).first;

      if (shuffleOpt) {
        loadedQuestions = loadedQuestions.map((q) {
          if (q.options == null) return q;
          final shuffledOptions = List<OptionItem>.from(q.options!)..shuffle();
          return Question(
            id: q.id,
            type: q.type,
            stem: q.stem,
            options: shuffledOptions,
            marks: q.marks,
            expectsLatex: q.expectsLatex,
            order: q.order,
            imageUrl: q.imageUrl,
          );
        }).toList();
      }

      if (shuffleQ) {
        loadedQuestions.shuffle();
      } else {
        loadedQuestions.sort((a, b) => a.order.compareTo(b.order));
      }

      final ansSnap =
          await _db.child('attemptAnswers/${widget.attemptId}').get();
      if (ansSnap.exists) {
        final existing = Map<String, dynamic>.from(ansSnap.value as Map);
        for (final entry in existing.entries) {
          final qid = entry.key;
          final qData = Map<String, dynamic>.from(entry.value as Map);
          if (qData['selected'] != null) {
            _selected[qid] = List<String>.from(qData['selected']);
          }
          if (qData['text'] != null) {
            _controllers[qid] = TextEditingController(text: qData['text']);
          }
          if (qData['answerImageUrl'] != null) {
            _writtenImages[qid] = qData['answerImageUrl'];
          }
        }
      }

      if (mounted) {
        setState(() {
          attempt = attData;
          questions = loadedQuestions;
          _allowStudentUpload = allowUpload;
          _examTitle = examTitle;
          _lastSynced = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _updateSyncStatus() {
    if (mounted) setState(() => _lastSynced = DateTime.now());
  }

  Future<void> _uploadAnswerImage(String qid) async {
    // Guard the picker call so the gallery opening (which triggers an
    // `inactive`/`paused` lifecycle event) isn't mistaken for a tab switch.
    final image = await _runWithSystemUIException(
      () => ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 60),
    );
    if (image == null) return;

    setState(() => _uploadingStates[qid] = true);

    try {
      final Uint8List bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final request = http.MultipartRequest(
          'POST', Uri.parse('https://api.imgbb.com/1/upload'));
      request.fields['key'] = _imgBBKey;
      request.fields['image'] = base64Image;

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200) {
        final url = jsonResponse['data']['url'];
        if (!mounted) return;
        setState(() => _writtenImages[qid] = url);
        await _db.child('attemptAnswers/${widget.attemptId}/$qid').update({
          'answerImageUrl': url,
          'savedAt': ServerValue.timestamp,
        });
        _updateSyncStatus();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Upload failed")));
    } finally {
      if (mounted) {
        setState(() => _uploadingStates[qid] = false);
      }
    }
  }

  void _handleOptionTap(String qid, String optId, String type) async {
    final current = List<String>.from(_selected[qid] ?? <String>[]);
    if (type == 'mcq_single' || type == 'mcq') {
      current.clear();
      current.add(optId);
    } else {
      current.contains(optId) ? current.remove(optId) : current.add(optId);
    }
    setState(() => _selected[qid] = current);
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

  Future<void> _submit() async {
    if (_submitting || !mounted) return;
    setState(() => _submitting = true);
    try {
      final String examId = (attempt?['examId'] ?? '').toString();

      // 1. Fetch answer keys if available (try examAnswerKeys first, then exams/$examId/questions)
      final Map<String, List<String>> answerKeys = {};
      if (examId.isNotEmpty) {
        try {
          final keySnap = await _db.child('examAnswerKeys/$examId').get();
          if (keySnap.exists && keySnap.value is Map) {
            final raw = Map<String, dynamic>.from(keySnap.value as Map);
            raw.forEach((k, v) {
              if (v is Map && v['correctOptions'] != null) {
                answerKeys[k] = List<String>.from(v['correctOptions']);
              }
            });
          }
        } catch (_) {}

        if (answerKeys.isEmpty) {
          try {
            final qSnap = await _db.child('exams/$examId/questions').get();
            if (qSnap.exists && qSnap.value is Map) {
              final raw = Map<String, dynamic>.from(qSnap.value as Map);
              raw.forEach((k, v) {
                if (v is Map && v['correctOptions'] != null) {
                  answerKeys[k] = List<String>.from(v['correctOptions']);
                }
              });
            }
          } catch (_) {}
        }
      }

      int totalPossible = 0;
      num autoScore = 0;
      bool hasWrittenContent = false;
      final Map<String, num> perQuestionAuto = {};
      final Map<String, dynamic> updates = {};

      for (final q in questions) {
        if (q.type == 'info_block') continue;
        final int qMarks = q.marks;
        totalPossible += qMarks;

        if (q.type == 'written') {
          hasWrittenContent = true;
        } else if (q.type.startsWith('mcq')) {
          if (answerKeys.containsKey(q.id)) {
            final List<String> correct = answerKeys[q.id] ?? [];
            final List<String> selected = _selected[q.id] ?? [];
            final bool isCorrect = selected.length == correct.length &&
                selected.every((e) => correct.contains(e));
            final num score = isCorrect ? qMarks : 0;
            autoScore += score;
            perQuestionAuto[q.id] = score;
            updates['attemptAnswers/${widget.attemptId}/${q.id}/autoPoints'] = score;
          }
        }
      }

      final bool isFullyGraded = !hasWrittenContent && answerKeys.isNotEmpty;
      final String finalStatus = isFullyGraded ? 'completed' : 'submitted';

      // Update attempts/$attemptId
      updates['attempts/${widget.attemptId}/status'] = finalStatus;
      updates['attempts/${widget.attemptId}/totalPossible'] = totalPossible;
      updates['attempts/${widget.attemptId}/score'] = autoScore;
      updates['attempts/${widget.attemptId}/totalPoints'] = autoScore;
      updates['attempts/${widget.attemptId}/isManualGraded'] = hasWrittenContent || answerKeys.isEmpty;
      updates['attempts/${widget.attemptId}/submittedAt'] = ServerValue.timestamp;
      updates['attempts/${widget.attemptId}/examTitle'] = _examTitle;

      // Update results/$attemptId
      updates['results/${widget.attemptId}/status'] = isFullyGraded ? 'completed' : 'awaiting_manual';
      updates['results/${widget.attemptId}/score'] = autoScore;
      updates['results/${widget.attemptId}/totalPoints'] = autoScore;
      updates['results/${widget.attemptId}/totalPossible'] = totalPossible;
      updates['results/${widget.attemptId}/isManualGraded'] = hasWrittenContent || answerKeys.isEmpty;
      updates['results/${widget.attemptId}/auto'] = {
        'total': autoScore,
        'perQuestion': perQuestionAuto,
      };
      updates['results/${widget.attemptId}/perQuestion'] = perQuestionAuto;
      updates['results/${widget.attemptId}/submittedAt'] = ServerValue.timestamp;
      updates['results/${widget.attemptId}/updatedAt'] = ServerValue.timestamp;

      await _db.update(updates);
      if (mounted) context.go('/submitted/${widget.attemptId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Submit failed: $e")));
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _confirmAndSubmit() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Submission',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to end the quiz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('BACK', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2264D7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SUBMIT NOW',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm == true) _submit();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: Center(child: Text("Error: $_error")));
    }
    if (attempt == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final endTime = attempt!['endTime'] as int? ?? 0;
    const Color brandBlue = Color(0xFF2264D7);
    final String syncTime = _lastSynced != null
        ? DateFormat('HH:mm:ss').format(_lastSynced!)
        : "--:--";

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text(
          'Live Quiz',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
        ),
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
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: _isConnected
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    _isConnected ? "Synced" : "Offline",
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ]),
                Text("Last: $syncTime",
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
          IconButton(
              onPressed: _submitting ? null : _confirmAndSubmit,
              icon: const Icon(Icons.send_rounded)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.white,
                border:
                    Border(bottom: BorderSide(color: Colors.grey.shade300))),
            child: Center(
                child: (endTime > 0)
                    ? ExamTimer(endTimeMs: endTime, onTimeUp: _submit)
                    : const Text("No Time Limit")),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final q = questions[index];
                final qid = q.id;
                final type = q.type;
                final stem = q.stem.isNotEmpty ? q.stem : "Question missing";
                final imageUrl = q.imageUrl;
                final bool isInfo = type == 'info_block';

                final int displayNum = isInfo
                    ? 0
                    : questions
                        .take(index + 1)
                        .where((item) => item.type != 'info_block')
                        .length;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isInfo
                          ? brandBlue.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                    ),
                  ),
                  color:
                      isInfo ? brandBlue.withValues(alpha: 0.03) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isInfo)
                              Text('$displayNum. ',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            if (isInfo)
                              const Icon(Icons.info_outline,
                                  size: 20, color: brandBlue),
                            if (isInfo) const SizedBox(width: 8),
                            Expanded(
                                child: LatexText(stem, size: isInfo ? 15 : 16)),
                          ],
                        ),
                        if (imageUrl != null && imageUrl.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(imageUrl,
                                width: double.infinity, fit: BoxFit.contain),
                          ),
                        ],
                        if (!isInfo) const SizedBox(height: 20),

                        if (!isInfo) ...[
                          if (type == 'written') ...[
                            TextField(
                              controller: _controllers.putIfAbsent(
                                  qid, () => TextEditingController()),
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: 'Type your answer...',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              onChanged: (val) =>
                                  _handleWrittenChange(qid, val),
                            ),
                            const SizedBox(height: 12),
                            if (_allowStudentUpload) ...[
                              if (_writtenImages[qid] != null) ...[
                                Stack(children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(_writtenImages[qid]!,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.red,
                                      radius: 14,
                                      child: IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 14, color: Colors.white),
                                        onPressed: () => setState(
                                            () => _writtenImages[qid] = null),
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 8),
                              ],
                              OutlinedButton.icon(
                                onPressed: _uploadingStates[qid] == true
                                    ? null
                                    : () => _uploadAnswerImage(qid),
                                icon: _uploadingStates[qid] == true
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.camera_alt_outlined,
                                        size: 18),
                                label: Text(_uploadingStates[qid] == true
                                    ? 'Uploading...'
                                    : 'Attach Image Evidence'),
                              ),
                            ]
                          ] else if (q.options != null)
                            ...q.options!.map((opt) {
                              final optId = opt.id;
                              final isSelected =
                                  (_selected[qid] ?? []).contains(optId);
                              return GestureDetector(
                                onTap: () => _handleOptionTap(qid, optId, type),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? brandBlue.withValues(alpha: 0.05)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: isSelected
                                            ? brandBlue
                                            : Colors.grey.shade300,
                                        width: 1.5),
                                  ),
                                  child: Row(children: [
                                    Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.radio_button_off,
                                        color: isSelected
                                            ? brandBlue
                                            : Colors.grey,
                                        size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: LatexText(opt.text, size: 15)),
                                  ]),
                                ),
                              );
                            }),
                        ],
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
    if (mounted) setState(() => remaining = diff.clamp(0, 999999999));
    if (diff <= 60000 && diff > 0 && !_warned) {
      _warned = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showWarning();
      });
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('1 Minute Left!')
              ]),
              actions: [
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2264D7)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('GOT IT',
                        style: TextStyle(color: Colors.white)))
              ],
            ));
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
          color: isUrgent
              ? Colors.red.shade50
              : const Color(0xFF2264D7).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isUrgent ? Colors.red : const Color(0xFF2264D7))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined,
            size: 18, color: isUrgent ? Colors.red : const Color(0xFF2264D7)),
        const SizedBox(width: 8),
        Text('$hh:$mm:$ss',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: isUrgent ? Colors.red : const Color(0xFF2264D7),
                fontSize: 16)),
      ]),
    );
  }
}
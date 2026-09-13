import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../services/attempt_service.dart';
import '../../services/auth_service.dart';

class CandidateInfoScreen extends StatefulWidget {
  final String? examId;
  const CandidateInfoScreen({super.key, this.examId});

  @override
  State<CandidateInfoScreen> createState() => _CandidateInfoScreenState();
}

class _CandidateInfoScreenState extends State<CandidateInfoScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _db = FirebaseDatabase.instance.ref();
  final _attemptService = AttemptService();

  String? _token;
  String? _actualExamId;
  String? _examTitle;
  bool _isStarting = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        user = await AuthService().signInStudentAnonymously();
        if (user == null) {
          setState(() {
            _error = "Identity verification failed. Check internet.";
            _isLoading = false;
          });
          return;
        }
      }

      final inputId = widget.examId?.trim();
      if (inputId == null || inputId.isEmpty) {
        setState(() {
          _error = "No Quiz ID or Token provided.";
          _isLoading = false;
        });
        return;
      }

      final invalidCharRegex = RegExp(r'[.#$\[\]/]');
      if (invalidCharRegex.hasMatch(inputId)) {
        setState(() {
          _error = "Input contains invalid characters.";
          _isLoading = false;
        });
        return;
      }

      // 1. Resolve Token -> Exam ID mapping or direct Exam ID
      final tokenSnap = await _db.child('examTokens/$inputId').get();
      String? resolvedExamId;
      if (tokenSnap.exists) {
        _token = inputId;
        resolvedExamId = tokenSnap.child('examId').value?.toString();
        if (resolvedExamId == null || resolvedExamId.isEmpty) {
          setState(() {
            _error = 'Invalid token mapping. Contact instructor.';
            _isLoading = false;
          });
          return;
        }
      } else {
        _token = null;
        resolvedExamId = inputId;
      }

      // 2. Verify that the exam exists and is published (matching TokenLandingScreen)
      final examSnap = await _db.child('exams/$resolvedExamId').get();
      if (!examSnap.exists) {
        setState(() {
          _error = 'Exam no longer exists.';
          _isLoading = false;
        });
        return;
      }

      final isPublished = (examSnap.child('isPublished').value == true) ||
          (examSnap.child('status').value == 'published');
      if (!isPublished) {
        setState(() {
          _error = 'This exam is not yet active.';
          _isLoading = false;
        });
        return;
      }

      // 3. Check for prior attempt via atomic index check (matching TokenLandingScreen)
      final attemptKey = '${user.uid}_$resolvedExamId';
      final attemptIndexSnap = await _db.child('attemptIndex/$attemptKey').get();

      if (attemptIndexSnap.exists) {
        setState(() {
          _actualExamId = resolvedExamId;
          _error = 'You have already attempted this exam.';
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAlreadyTakenDialog();
        });
        return;
      }

      final title = examSnap.child('title').value?.toString() ?? 'Untitled Quiz';

      setState(() {
        _actualExamId = resolvedExamId;
        _examTitle = title;
      });
    } catch (e) {
      _error = "Initialization error: $e";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z]+").hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Registration',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: brandBlue))
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) _buildErrorCard(),

                if (_examTitle != null) ...[
                  const Text("YOU ARE JOINING:",
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text(_examTitle!,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: brandBlue, fontFamily: 'Inter')),
                  const SizedBox(height: 32),
                ],

                const Text("Enter your credentials to begin.",
                  style: TextStyle(color: Color(0xFF475569), fontSize: 15, fontFamily: 'Inter')),
                const SizedBox(height: 24),

                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: (_isStarting || _actualExamId == null || _error != null) ? null : _startExam,
                    child: _isStarting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('START SESSION',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.2, fontFamily: 'Inter')),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text("Ensure you have a stable connection. Progress is auto-synced.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontFamily: 'Inter')),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF2264D7), size: 20),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2264D7), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFEE2E2))
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w500, fontFamily: 'Inter'))),
        ],
      ),
    );
  }

  // --- SHOW WARNING POPUP DIALOG ---
  void _showAlreadyTakenDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Session Restrained', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'You have already initialized or submitted an attempt for this examination. Multiple completions are strictly blocked by the system.',
          style: TextStyle(fontFamily: 'Inter', color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2264D7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/results'); // Navigates directly to score checking portal
            },
            child: const Text('VIEW RESULTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _startExam() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || email.isEmpty || !_isValidEmail(email)) {
      setState(() => _error = 'Please provide a valid name and email.');
      return;
    }

    setState(() {
      _isStarting = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Session expired. Please refresh the page.";

      if (_actualExamId == null) {
        throw "Quiz not found. Please reload the page.";
      }

      final attemptKey = '${user.uid}_$_actualExamId';

      // 1. Check for prior attempt via atomic index check (matching TokenLandingScreen)
      final attemptIndexSnap = await _db.child('attemptIndex/$attemptKey').get();
      if (attemptIndexSnap.exists) {
        if (mounted) {
          setState(() => _isStarting = false);
          _showAlreadyTakenDialog();
        }
        return;
      }

      // 2. Fetch exam metadata for duration and verify active status
      final examSnap = await _db.child('exams/$_actualExamId').get();
      if (!examSnap.exists) {
        throw "The quiz was not found or has been deleted.";
      }

      final examData = Map<String, dynamic>.from(examSnap.value as Map);
      final isPublished = (examData['isPublished'] == true) ||
          (examData['status'] == 'published');
      if (!isPublished) {
        throw "This exam is not yet active.";
      }

      final int durationMs = (examData['durationMs'] as num?)?.toInt() ?? 3600000;

      // 3. Start attempt using AttemptService
      final attemptId = await _attemptService.startAttempt(
        examId: _actualExamId!,
        uid: user.uid,
        candidate: {'name': name, 'email': email},
        durationMs: durationMs,
        token: _token,
      );

      // 4. Record to attemptIndex to prevent duplicate attempts
      await _db.child('attemptIndex/$attemptKey').set(attemptId);

      if (mounted) {
        _nameController.clear();
        _emailController.clear();
        context.go('/exam/$attemptId');
      }
    } catch (err) {
      if (mounted) setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }
}
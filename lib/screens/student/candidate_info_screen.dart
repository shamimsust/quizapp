import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';

class CandidateInfoScreen extends StatefulWidget {
  final String? examId; 
  const CandidateInfoScreen({super.key, this.examId});

  @override
  State<CandidateInfoScreen> createState() => _CandidateInfoScreenState();
}

class _CandidateInfoScreenState extends State<CandidateInfoScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _db = FirebaseDatabase.instance.ref();

  String? _token;
  String? _actualExamId; // The real ID from the 'exams' collection
  bool _starting = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      // 1. Ensure Auth
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      // 2. Identify if the passed ID is a Token or a direct Exam ID
      // If the URL is /candidate/9lwddR..., 'widget.examId' contains that string.
      final inputId = widget.examId?.trim();

      if (inputId == null || inputId.isEmpty) {
        setState(() { _error = "No Exam or Token provided."; _loading = false; });
        return;
      }

      // 3. Try to resolve Token -> Exam mapping
      // First, check the 'examTokens' (or 'tokens') collection
      final tokenSnap = await _db.child('examTokens').child(inputId).get();
      
      if (tokenSnap.exists) {
        _token = inputId;
        final data = Map<dynamic, dynamic>.from(tokenSnap.value as Map);
        _actualExamId = data['examId']?.toString();
      } else {
        // If it's not a token, assume it's a direct Exam ID
        _actualExamId = inputId;
      }

      // 4. Verify the Exam actually exists in the 'exams' folder
      if (_actualExamId != null) {
        final examCheck = await _db.child('exams').child(_actualExamId!).get();
        if (!examCheck.exists) {
          _error = "Exam not found. Please check your link.";
        }
      } else {
        _error = "Invalid Token.";
      }

    } catch (e) {
      _error = "Initialization error: $e";
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z]+") .hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Candidate Registration', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: brandBlue))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) 
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                    child: Text("Error: $_error", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                  ),
                
                const Text("Enter your details to begin the examination.", style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
                const SizedBox(height: 24),
                
                TextField(
                  controller: _name, 
                  decoration: InputDecoration(
                    labelText: 'Full Name', 
                    filled: true, 
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                  )
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _email, 
                  decoration: InputDecoration(
                    labelText: 'Email Address', 
                    filled: true, 
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                  ), 
                  keyboardType: TextInputType.emailAddress
                ),
                
                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandBlue, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: (_starting || _actualExamId == null || _error != null) ? null : _startExam,
                    child: _starting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Start Exam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
    );
  }

  Future<void> _startExam() async {
    final name = _name.text.trim();
    final email = _email.text.trim();

    if (name.isEmpty || email.isEmpty || !_isValidEmail(email)) {
      setState(() => _error = 'Please provide a valid name and email.');
      return;
    }

    setState(() { _starting = true; _error = null; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      
      if (uid == null) throw "Authentication failed. Refresh and try again.";

      // Fetch Exam Data for Duration
      final examSnap = await _db.child('exams').child(_actualExamId!).get();
      if (!examSnap.exists) throw "The exam settings have been removed by admin.";

      final examData = Map<dynamic, dynamic>.from(examSnap.value as Map);
      final int durationMs = examData['durationMs'] ?? 3600000; // Default 1 hour

      final newAttemptRef = _db.child('attempts').push();
      final attemptId = newAttemptRef.key;
      final now = DateTime.now().millisecondsSinceEpoch;

      await newAttemptRef.set({
        'examId': _actualExamId,
        'userId': uid,
        'candidate': {'name': name, 'email': email},
        'status': 'in_progress',
        'startTime': now,
        'endTime': now + durationMs,
        'createdFromToken': _token,
      });

      if (mounted) context.go('/exam/$attemptId');

    } catch (err) {
      if (mounted) setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }
}
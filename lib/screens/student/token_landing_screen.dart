import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for direct check

class TokenLandingScreen extends StatefulWidget {
  final String? token;
  const TokenLandingScreen({super.key, this.token});

  @override
  State<TokenLandingScreen> createState() => _TokenLandingScreenState();
}

class _TokenLandingScreenState extends State<TokenLandingScreen> {
  final _tokenController = TextEditingController();
  String? _examId;
  String? _error;
  bool _isLoading = false;
  final Color _primaryBlue = const Color(0xFF2264D7); 

  @override
  void initState() {
    super.initState();
    if (widget.token != null) {
      _tokenController.text = widget.token!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _validateToken());
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _validateToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _examId = null;
    });

    try {
      // --- FIX: AUTHENTICATE FIRST ---
      // This prevents the "Connection error" caused by permission denied
      if (FirebaseAuth.instance.currentUser == null) {
        await AuthService().signInStudentAnonymously();
      }

      // --- FIX: VALIDATE TOKEN PATH SEGMENT ---
      // Prevents "Invalid token in path" error
      final invalidCharRegex = RegExp(r'[.#$\[\]/]');
      if (invalidCharRegex.hasMatch(token)) {
        setState(() => _error = 'Token contains invalid characters.');
        return;
      }

      final snap = await FirebaseDatabase.instance.ref('examTokens').child(token).get();
      
      if (!snap.exists) {
        setState(() => _error = 'Invalid token. Please check the code.');
        return;
      }

      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final fetchedExamId = data['examId']?.toString();

      if (fetchedExamId == null || fetchedExamId.isEmpty || invalidCharRegex.hasMatch(fetchedExamId)) {
        setState(() => _error = 'This token points to an invalid exam configuration.');
        return;
      }

      setState(() => _examId = fetchedExamId);
    } catch (e) {
      //
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F6),
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () => context.push('/admin/signin'),
          child: const Text('Join Exam Room', style: TextStyle(fontFamily: 'Inter')),
        ),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
            onPressed: () => context.push('/admin/signin'),
            tooltip: 'Admin Login',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your invitation token to proceed to the exam instructions.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _tokenController,
              onChanged: (_) => setState(() { _examId = null; _error = null; }),
              decoration: InputDecoration(
                labelText: 'Exam Token',
                hintText: 'e.g., MATH-FINAL-2026',
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: _isLoading ? null : _validateToken,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              )
            else if (_examId != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Token Validated Successfully!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),

            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _examId == null ? null : _handleContinue,
                child: const Text(
                  'Continue to Details',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _handleContinue() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    if (mounted) {
      // Token is already validated, proceed to the candidate details screen
      context.go('/candidate/$token');
    }
  }
}
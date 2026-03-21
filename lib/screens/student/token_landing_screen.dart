import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

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
    
    // START AUTH IMMEDIATELY: Fixes the 'verify twice' race condition
    _prepareAuth();

    if (widget.token != null && widget.token!.isNotEmpty) {
      _tokenController.text = widget.token!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _validateToken());
    }
  }

  Future<void> _prepareAuth() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await AuthService().signInStudentAnonymously();
      }
    } catch (e) {
      debugPrint("Pre-auth background error: $e");
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
      // 1. ENSURE AUTH IS READY: Await if background sign-in isn't done
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        user = await AuthService().signInStudentAnonymously();
        if (user == null) {
          setState(() => _error = 'Identity verification failed. Check internet.');
          return;
        }
      }

      // 2. Sanitize Input
      final invalidCharRegex = RegExp(r'[.#$\[\]/]');
      if (invalidCharRegex.hasMatch(token)) {
        setState(() => _error = 'Token contains invalid characters.');
        return;
      }

      // 3. Verify Token
      final tokenSnap = await FirebaseDatabase.instance.ref('examTokens').child(token).get();
      
      if (!tokenSnap.exists) {
        setState(() => _error = 'Invalid token. Please check the code.');
        return;
      }

      final tokenData = Map<dynamic, dynamic>.from(tokenSnap.value as Map);
      final fetchedExamId = tokenData['examId']?.toString();

      if (fetchedExamId == null || fetchedExamId.isEmpty) {
        setState(() => _error = 'This token points to an invalid quiz.');
        return;
      }

      // 4. GUARD: Check if Exam is Published
      final examSnap = await FirebaseDatabase.instance.ref('exams').child(fetchedExamId).get();
      
      if (!examSnap.exists) {
        setState(() => _error = 'The associated exam has been removed.');
        return;
      }

      final examData = Map<dynamic, dynamic>.from(examSnap.value as Map);
      final String status = examData['status']?.toString() ?? 'draft';

      if (status != 'published') {
        setState(() => _error = 'This exam is currently in DRAFT mode and not accepting entries.');
        return;
      }

      // Success
      setState(() => _examId = fetchedExamId);
      
    } catch (e) {
      debugPrint("Validation Error: $e");
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Join Quiz Room', 
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 16)),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => context.push('/admin/signin'),
            tooltip: 'Admin Portal',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the invitation token provided by Tariqul Sir to proceed.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            
            TextField(
              controller: _tokenController,
              textCapitalization: TextCapitalization.characters,
              onChanged: (val) {
                if (_examId != null || _error != null) {
                  setState(() { _examId = null; _error = null; });
                }
              },
              decoration: InputDecoration(
                labelText: 'Quiz Token',
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                hintText: 'e.g., MATH-101',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.vpn_key_outlined, color: _primaryBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _primaryBlue, width: 2)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _isLoading ? null : _validateToken,
                ),
              ),
              onSubmitted: (_) => _validateToken(),
            ),
            
            const SizedBox(height: 24),
            
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              _buildFeedbackBox(
                icon: Icons.error_outline_rounded,
                color: Colors.red,
                text: _error!,
              )
            else if (_examId != null)
              _buildFeedbackBox(
                icon: Icons.check_circle_rounded,
                color: Colors.green,
                text: 'Token Validated! Click below to start registration.',
              ),

            const Spacer(),

            Center(
              child: Column(
                children: [
                  const Text("Looking for your results?", 
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                  TextButton(
                    onPressed: () => context.push('/results'),
                    child: Text("Access Result Portal", 
                      style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w900, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                onPressed: _examId == null ? null : _handleContinue,
                child: const Text(
                  'CONTINUE TO REGISTRATION',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackBox({required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14))),
        ],
      ),
    );
  }

  void _handleContinue() {
    final token = _tokenController.text.trim();
    context.go('/candidate/$token');
  }
}
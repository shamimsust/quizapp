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
    // If a token is passed via URL/Deep link, auto-validate it
    if (widget.token != null && widget.token!.isNotEmpty) {
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
      // 1. Ensure the student is authenticated anonymously to read from DB
      if (FirebaseAuth.instance.currentUser == null) {
        await AuthService().signInStudentAnonymously();
      }

      // 2. Sanitize: Firebase paths cannot contain certain characters
      final invalidCharRegex = RegExp(r'[.#$\[\]/]');
      if (invalidCharRegex.hasMatch(token)) {
        setState(() => _error = 'Token contains invalid characters.');
        return;
      }

      // 3. Check Realtime Database
      final snap = await FirebaseDatabase.instance.ref('examTokens').child(token).get();
      
      if (!snap.exists) {
        setState(() => _error = 'Invalid token. Please check the code.');
        return;
      }

      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final fetchedExamId = data['examId']?.toString();

      if (fetchedExamId == null || fetchedExamId.isEmpty) {
        setState(() => _error = 'This token points to an invalid quiz configuration.');
        return;
      }

      setState(() => _examId = fetchedExamId);
    } catch (e) {
      debugPrint("Token Validation Error: $e");
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
        title: const Text('Join Quiz Room', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
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
              'Enter the invitation token provided by your instructor to proceed.',
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),
            const SizedBox(height: 32),
            
            // TOKEN INPUT
            TextField(
              controller: _tokenController,
              textCapitalization: TextCapitalization.characters,
              onChanged: (val) {
                // Reset state if they change the token after validation
                if (_examId != null || _error != null) {
                  setState(() { _examId = null; _error = null; });
                }
              },
              decoration: InputDecoration(
                labelText: 'Quiz Token',
                hintText: 'e.g., MATH-101',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _isLoading ? null : _validateToken,
                ),
              ),
              onSubmitted: (_) => _validateToken(),
            ),
            
            const SizedBox(height: 24),
            
            // LOADING & FEEDBACK STATES
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _buildFeedbackBox(
                icon: Icons.error_outline,
                color: Colors.red,
                text: _error!,
              )
            else if (_examId != null)
              _buildFeedbackBox(
                icon: Icons.check_circle_rounded,
                color: Colors.green,
                text: 'Token Validated! Click below to continue.',
              ),

            const Spacer(),
            
            // ACTION BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _examId == null ? null : _handleContinue,
                child: const Text(
                  'Continue to Registration',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _handleContinue() {
    final token = _tokenController.text.trim();
    context.go('/candidate/$token');
  }
}
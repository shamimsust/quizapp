import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';

class ResultLookupScreen extends StatefulWidget {
  const ResultLookupScreen({super.key});

  @override
  State<ResultLookupScreen> createState() => _ResultLookupScreenState();
}

class _ResultLookupScreenState extends State<ResultLookupScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isLoading = false;

  void _searchResult() async {
    final email = _emailController.text.trim().toLowerCase();
    final token = _tokenController.text.trim();

    if (email.isEmpty || token.isEmpty) {
      _showMsg("Please enter both email and token.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Fetch all attempts linked to this email
      final snapshot = await FirebaseDatabase.instance.ref('attempts')
          .orderByChild('candidate/email')
          .equalTo(email)
          .get();

      if (snapshot.exists) {
        final attempts = Map<dynamic, dynamic>.from(snapshot.value as Map);
        String? targetId;

        // 2. First Pass: Check if 'createdFromToken' matches the input exactly
        for (var entry in attempts.entries) {
          final data = Map<String, dynamic>.from(entry.value);
          final String? dbToken = data['createdFromToken']?.toString();
          final String? dbExamId = data['examId']?.toString();

          if (dbToken == token || dbExamId == token) {
            targetId = entry.key.toString();
            break;
          }
        }

        // 3. Second Pass: If not found, check the 'examTokens' node to find the linked examId
        if (targetId == null) {
          final tokenSnap = await FirebaseDatabase.instance.ref('examTokens/$token').get();
          if (tokenSnap.exists) {
            final tokenData = Map<String, dynamic>.from(tokenSnap.value as Map);
            final String linkedExamId = tokenData['examId'] ?? '';

            for (var entry in attempts.entries) {
              final data = Map<String, dynamic>.from(entry.value);
              if (data['examId'] == linkedExamId) {
                targetId = entry.key.toString();
                break;
              }
            }
          }
        }

        if (targetId != null) {
          if (!mounted) return;
          // Successfully found the attempt!
          context.push('/result/$targetId');
        } else {
          _showMsg("No results found for this token.");
        }
      } else {
        _showMsg("No record found for this email.");
      }
    } catch (e) {
      debugPrint("Lookup Error: $e");
      _showMsg("Error searching for results.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), behavior: SnackBarBehavior.floating)
  );

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("RESULT PORTAL", 
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.receipt_long_rounded, size: 80, color: brandBlue),
              const SizedBox(height: 24),
              const Text("Check Performance", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              const Text("Enter your credentials to view your grade", 
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
              const SizedBox(height: 40),
              
              _buildTextField(
                controller: _emailController,
                label: "Email Address",
                hint: "Enter registered email",
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _tokenController,
                label: "Exam Token",
                hint: "Enter your unique access token",
                icon: Icons.vpn_key_outlined,
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _searchResult,
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("ACCESS MY RESULT", 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text("Back to Home", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.normal),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2264D7), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
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

    if (email.isEmpty || token.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseDatabase.instance.ref('attempts')
          .orderByChild('candidate/email')
          .equalTo(email)
          .get();

      if (snapshot.exists) {
        final attempts = Map<dynamic, dynamic>.from(snapshot.value as Map);
        String? targetId;

        for (var entry in attempts.entries) {
          final data = Map<String, dynamic>.from(entry.value);
          // Check if token matches (could be examToken or examId)
          if (data['examToken'] == token || data['examId'] == token) {
            targetId = entry.key;
            break;
          }
        }

        if (targetId != null) {
          if (!mounted) return;
          // USE GOROUTER NAVIGATION
          context.push('/result/$targetId');
        } else {
          _showMsg("No results found for this token.");
        }
      } else {
        _showMsg("No record found for this email.");
      }
    } catch (e) {
      _showMsg("Error searching for results.");
    }
    setState(() => _isLoading = false);
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("RESULT PORTAL", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_rounded, size: 64, color: Color(0xFF2264D7)),
            const SizedBox(height: 16),
            const Text("Find your Manual Grade", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "Email used for exam",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: "Exam Token",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2264D7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _searchResult,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("ACCESS MY RESULT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
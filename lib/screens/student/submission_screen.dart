import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SubmissionScreen extends StatefulWidget {
  final String attemptId;
  const SubmissionScreen({super.key, required this.attemptId});

  @override
  State<SubmissionScreen> createState() => _SubmissionScreenState();
}

class _SubmissionScreenState extends State<SubmissionScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToResult();
  }

  Future<void> _navigateToResult() async {
    // 2-second delay to ensure auto-grading writes are finalized in Firebase
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      context.go('/result/${widget.attemptId}'); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Submission', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // FIX: Added SingleChildScrollView and Center/ConstrainedBox for layout safety
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2264D7).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded, 
                          size: 100, 
                          color: Color(0xFF2264D7)
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Exam Submitted!',
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          fontFamily: 'Inter',
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Attempt ID: ${widget.attemptId}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Please stay on this screen while we\ncalculate your final results...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16, 
                          color: Colors.black54,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const SizedBox(
                        width: 150,
                        child: LinearProgressIndicator(
                          color: Color(0xFF2264D7),
                          backgroundColor: Color(0xFFE0E0E0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}
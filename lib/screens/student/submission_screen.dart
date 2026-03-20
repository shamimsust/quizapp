import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SubmissionScreen extends StatefulWidget {
  final String attemptId;
  const SubmissionScreen({super.key, required this.attemptId});

  @override
  State<SubmissionScreen> createState() => _SubmissionScreenState();
}

class _SubmissionScreenState extends State<SubmissionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for the success icon
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1200)
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );

    _navigateToResult();
  }

  Future<void> _navigateToResult() async {
    // 3-second delay allows Firebase functions to finish calculating auto-grades
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      context.go('/result/${widget.attemptId}'); 
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF2264D7);

    return PopScope(
      canPop: false, // Strictly prevents navigating back to the exam
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC), // Matching your app's background
        appBar: AppBar(
          title: const Text('SUBMISSION', 
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false, 
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: brandBlue.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: brandBlue.withOpacity(0.1), width: 2),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded, 
                      size: 110, 
                      color: brandBlue
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                const Text(
                  'Exam Submitted!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.w900, 
                    fontFamily: 'Inter',
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    'SESSION ID: ${widget.attemptId.toUpperCase()}',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Processing your results...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, 
                    color: Color(0xFF64748B),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please stay on this page.',
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
                const SizedBox(height: 56),
                const SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    color: brandBlue,
                    backgroundColor: Color(0xFFE2E8F0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
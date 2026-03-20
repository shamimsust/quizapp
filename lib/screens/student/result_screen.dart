import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';

class ResultScreen extends ConsumerWidget {
  final String attemptId;
  const ResultScreen({super.key, required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Exam Result', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder(
        future: FirebaseDatabase.instance.ref('attempts/$attemptId').get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2264D7)));
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Could not load results.'));
          }

          final data = Map<String, dynamic>.from(snapshot.data!.value as Map);
          final status = data['status'] ?? 'unknown';
          final score = data['score'];
          final totalPossible = data['totalPossible'];
          
          final bool isPending = status == 'submitted'; 
          final String scoreText = (score != null && totalPossible != null) 
              ? '$score / $totalPossible' 
              : 'Pending';

          // FIX: Wrapped in SingleChildScrollView to prevent bottom overflow
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Changed to min
                children: [
                  Icon(
                    isPending ? Icons.hourglass_empty_rounded : Icons.stars_rounded, 
                    size: 80, // Slightly reduced size to save space
                    color: const Color(0xFF2264D7)
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isPending ? 'Submission Received' : 'Exam Completed!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold, 
                      fontFamily: 'Inter',
                      color: Color(0xFF1A1A1A)
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Score Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2264D7).withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'FINAL SCORE',
                          style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          scoreText,
                          style: const TextStyle(
                            fontSize: 36, 
                            fontWeight: FontWeight.w900, 
                            color: Color(0xFF2264D7),
                            fontFamily: 'Inter'
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    isPending 
                      ? 'Your exam contains questions that require manual grading. Your score will be updated soon.'
                      : 'Great job! Your exam has been successfully auto-graded.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                  ),
                  
                  const SizedBox(height: 48), // Replaced Spacer() with fixed height
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2264D7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => context.go('/'), 
                      child: const Text(
                        'Return to Dashboard', 
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
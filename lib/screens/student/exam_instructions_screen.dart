import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/exam_providers.dart';

class ExamInstructionsScreen extends ConsumerWidget {
  final String examId;
  const ExamInstructionsScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the exam metadata for this specific ID
    final examAsync = ref.watch(examProvider(examId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Instructions', style: TextStyle(fontFamily: 'Inter')), //
        backgroundColor: const Color(0xFF2264D7), // #2264D7
      ),
      body: examAsync.when(
        data: (exam) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exam?.title ?? 'Untitled Exam',
                style: const TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold, 
                  fontFamily: 'Inter', //
                ),
              ),
              const SizedBox(height: 16),
              // Display duration converted from milliseconds
              Text('Duration: ${(exam?.durationMs ?? 0) ~/ 60000} minutes'),
              const Divider(height: 40),
              const Text(
                'Instructions:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text('1. Ensure you have a stable internet connection.'),
              const Text('2. Do not refresh or leave the page once the exam starts.'),
              const Text('3. All mathematical answers should be entered in the LaTeX field.'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2264D7), //
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    // Navigate to the candidate info screen to start the attempt
                    context.go('/candidate', extra: {'examId': examId});
                  },
                  child: const Text('I Understand, Continue', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading instructions: $err')),
      ),
    );
  }
}
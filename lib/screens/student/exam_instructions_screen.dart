import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/exam_providers.dart';

class ExamInstructionsScreen extends ConsumerWidget {
  final String examId;
  const ExamInstructionsScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const Color brandBlue = Color.fromRGBO(34, 100, 215, 1);
    final examAsync = ref.watch(examProvider(examId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Exam Preparation', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: examAsync.when(
        data: (exam) {
          if (exam == null) return const Center(child: Text('Exam not found.'));

          final int durationMin = exam.durationMs ~/ 60000;
          // Check the grading mode we defined in ExamBuilder
          final bool isManual = exam.isManualGrading;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  _buildHeaderCard(exam.title, durationMin, isManual, brandBlue),
                  
                  const SizedBox(height: 32),
                  
                  const Text('Instructions & Rules', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 16),
                  
                  _buildInstructionItem(Icons.wifi, 'Stable Connection', 'Ensure you have a reliable internet connection before starting.'),
                  _buildInstructionItem(Icons.block, 'No Refreshing', 'Refreshing or leaving the page may result in immediate submission.'),
                  _buildInstructionItem(Icons.functions, 'LaTeX Support', 'Use the dedicated math field for formulas and equations.'),
                  _buildInstructionItem(Icons.history, 'Auto-Save', 'Your progress is synced in real-time. If you disconnect, just log back in.'),

                  const SizedBox(height: 40),
                  
                  // Start Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => context.go('/candidate', extra: {'examId': examId}),
                      child: const Text('I Understand, Start Quiz', 
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('By clicking start, the timer will begin immediately.', 
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: brandBlue)),
        error: (err, _) => Center(child: Text('Error loading instructions: $err')),
      ),
    );
  }

  Widget _buildHeaderCard(String title, int duration, bool isManual, Color brandBlue) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetaBadge(Icons.timer_outlined, '$duration Min', brandBlue),
              const SizedBox(width: 12),
              _buildMetaBadge(
                isManual ? Icons.rate_review_outlined : Icons.bolt, 
                isManual ? 'Manual Grading' : 'Auto-Graded', 
                isManual ? Colors.orange.shade800 : Colors.green.shade700
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
            child: Icon(icon, size: 18, color: const Color(0xFF2264D7)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(desc, style: const TextStyle(fontSize: 13, color: Colors.blueGrey, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
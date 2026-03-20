import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String attemptId;
  const ResultScreen({super.key, required this.attemptId});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  Key _refreshKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('EXAM RESULT', 
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false, 
      ),
      body: RefreshIndicator(
        color: brandBlue,
        onRefresh: () async {
          setState(() { _refreshKey = UniqueKey(); });
        },
        child: FutureBuilder(
          key: _refreshKey,
          future: FirebaseDatabase.instance.ref('attempts/${widget.attemptId}').get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: brandBlue));
            }

            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
              return _buildErrorState();
            }

            final data = Map<String, dynamic>.from(snapshot.data!.value as Map);
            
            // LOGIC FIX: Check both status and if the exam requires manual grading
            final String status = data['status'] ?? 'submitted';
            final bool isManualRequired = data['isManualGrading'] ?? false;
            final bool isPending = status == 'submitted' || status == 'pending_review';
            
            final num score = data['score'] ?? 0;
            final num total = data['totalPossible'] ?? 0;
            final double percentage = (total > 0) ? (score / total) * 100 : 0;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: Column(
                  children: [
                    _buildIllustration(isPending, brandBlue),
                    const SizedBox(height: 32),
                    
                    Text(
                      isPending ? 'Submission Received!' : 'Quiz Completed!',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'Inter', color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        isPending 
                          ? 'Your responses are safely stored. A teacher will review your written answers shortly.' 
                          : 'Great job! Your final results have been calculated and verified.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.5, fontFamily: 'Inter'),
                      ),
                    ),

                    const SizedBox(height: 48),
                    _buildScoreCard(score, total, percentage, isPending, brandBlue),
                    const SizedBox(height: 48),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () => context.go('/'), 
                        child: const Text('RETURN TO HOME', 
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.1, fontFamily: 'Inter')),
                      ),
                    ),
                    
                    if (isPending) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh_rounded, size: 14, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text("Pull down to check for updates", 
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400, fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIllustration(bool isPending, Color brandBlue) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: isPending ? const Color(0xFFFFF7ED) : brandBlue.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
        ),
        Icon(
          isPending ? Icons.auto_awesome_outlined : Icons.emoji_events_rounded, 
          size: 70, 
          color: isPending ? Colors.orange.shade600 : brandBlue
        ),
      ],
    );
  }

  Widget _buildScoreCard(num score, num total, double percent, bool isPending, Color brandBlue) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 30, offset: const Offset(0, 15))
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Text(
            isPending ? 'PRELIMINARY SCORE' : 'FINAL SCORE',
            style: const TextStyle(fontSize: 12, letterSpacing: 2.0, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$score', 
                style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: isPending ? Colors.orange.shade800 : brandBlue, fontFamily: 'Inter')),
              Text(' / $total', 
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1), fontFamily: 'Inter')),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isPending ? const Color(0xFFFFF7ED) : brandBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: isPending ? Colors.orange.shade100 : brandBlue.withOpacity(0.1)),
            ),
            child: Text(
              isPending ? "GRADING IN PROGRESS" : "${percent.toStringAsFixed(1)}% ACCURACY",
              style: TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.w800, 
                color: isPending ? Colors.orange.shade900 : brandBlue,
                fontFamily: 'Inter'
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 60, color: Colors.red.shade300),
          const SizedBox(height: 20),
          const Text('Could not sync results.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Check your connection and try again.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => context.go('/'), 
            icon: const Icon(Icons.home_rounded),
            label: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}
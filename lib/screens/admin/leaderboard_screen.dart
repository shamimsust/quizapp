import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

// Helper class for data
class LeaderboardEntry {
  final String name;
  final String score;
  final String email;
  LeaderboardEntry({required this.name, required this.score, required this.email});
}

class AdminLeaderboardScreen extends StatefulWidget {
  const AdminLeaderboardScreen({super.key});

  @override
  State<AdminLeaderboardScreen> createState() => _AdminLeaderboardScreenState();
}

class _AdminLeaderboardScreenState extends State<AdminLeaderboardScreen> {
  final _db = FirebaseDatabase.instance.ref();
  String? _selectedExamId;
  String? _selectedExamTitle;

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_selectedExamId == null ? 'SELECT EXAM' : 'LEADERBOARD', 
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        leading: _selectedExamId != null 
          ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => setState(() => _selectedExamId = null))
          : IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: _selectedExamId == null ? _buildExamPicker() : _buildRankings(),
    );
  }

  Widget _buildExamPicker() {
    return StreamBuilder(
      stream: _db.child('exams').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final Map<dynamic, dynamic> exams = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
        
        return ListView(
          padding: const EdgeInsets.all(20),
          children: exams.entries.map((e) {
            final data = Map<String, dynamic>.from(e.value);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: Text(data['title'] ?? 'Untitled Exam', style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => setState(() {
                  _selectedExamId = e.key;
                  _selectedExamTitle = data['title'];
                }),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRankings() {
    return StreamBuilder(
      stream: _db.child('attempts').orderByChild('examId').equalTo(_selectedExamId).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: Text("No attempts found for this exam."));
        }

        final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
        List<LeaderboardEntry> entries = [];

        data.forEach((key, value) {
          final attempt = Map<String, dynamic>.from(value);
          if (attempt['status'] == 'completed') {
            entries.add(LeaderboardEntry(
              name: attempt['candidate']?['name'] ?? 'Student',
              email: attempt['candidate']?['email'] ?? '',
              score: (attempt['totalPoints'] ?? '0').toString(),
            ));
          }
        });

        // Sort by score descending
        entries.sort((a, b) => double.parse(b.score).compareTo(double.parse(a.score)));

        if (entries.isEmpty) return const Center(child: Text("No graded scripts yet."));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.grey.shade300 : const Color(0xFFF1F5F9)),
                  child: Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(entry.email, style: const TextStyle(fontSize: 12)),
                trailing: Text(entry.score, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2264D7))),
              ),
            );
          },
        );
      },
    );
  }
}
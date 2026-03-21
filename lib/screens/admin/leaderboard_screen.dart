import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class LeaderboardEntry {
  final String id; 
  final String name;
  final String score;
  final String email;
  LeaderboardEntry({required this.id, required this.name, required this.score, required this.email});
}

class AdminLeaderboardScreen extends StatefulWidget {
  const AdminLeaderboardScreen({super.key});

  @override
  State<AdminLeaderboardScreen> createState() => _AdminLeaderboardScreenState();
}

class _AdminLeaderboardScreenState extends State<AdminLeaderboardScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedExamId;
  String? _selectedExamTitle;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded), 
              onPressed: () => setState(() {
                _selectedExamId = null;
                _searchQuery = '';
                _searchController.clear();
              }),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded), 
              onPressed: () => Navigator.pop(context),
            ),
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
            final Map<String, dynamic> data = Map<String, dynamic>.from(e.value as Map);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: Text(data['title'] ?? 'Untitled Exam', style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => setState(() {
                  _selectedExamId = e.key as String;
                  _selectedExamTitle = data['title'] as String;
                }),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRankings() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedExamTitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_selectedExamTitle!.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.1)),
                ),
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search candidate name...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Expanded(
          child: StreamBuilder(
            stream: _db.child('attempts').orderByChild('examId').equalTo(_selectedExamId).onValue,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                return const Center(child: Text("No attempts found."));
              }

              final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
              final List<LeaderboardEntry> allEntries = [];

              data.forEach((key, value) {
                final Map<String, dynamic> attempt = Map<String, dynamic>.from(value as Map);
                if (attempt['status'] == 'completed') {
                  allEntries.add(LeaderboardEntry(
                    id: key as String,
                    name: attempt['candidate']?['name'] ?? 'Student',
                    email: attempt['candidate']?['email'] ?? '',
                    score: (attempt['totalPoints'] ?? '0').toString(),
                  ));
                }
              });

              final List<LeaderboardEntry> filteredEntries = allEntries.where((entry) {
                return entry.name.toLowerCase().contains(_searchQuery) || entry.email.toLowerCase().contains(_searchQuery);
              }).toList();

              filteredEntries.sort((a, b) => double.parse(b.score).compareTo(double.parse(a.score)));

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: filteredEntries.length,
                itemBuilder: (context, index) {
                  final LeaderboardEntry entry = filteredEntries[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: ListTile(
                      title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("View detailed review", style: TextStyle(fontSize: 11, color: Color(0xFF2264D7))),
                      onTap: () => _showGradeSummary(context, entry),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(entry.score, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2264D7))),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 20),
                            onPressed: () => _confirmReset(context, entry),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showGradeSummary(BuildContext context, LeaderboardEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: FutureBuilder(
            future: _db.child('attempts').child(entry.id).get(),
            builder: (context, attemptSnapshot) {
              if (!attemptSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final attemptData = Map<String, dynamic>.from(attemptSnapshot.data!.value as Map);
              final responses = Map<dynamic, dynamic>.from(attemptData['responses'] ?? {});
              
              int correct = 0;
              responses.forEach((k, v) { if (v['isCorrect'] == true) correct++; });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                            Text(entry.email, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF2264D7), borderRadius: BorderRadius.circular(12)),
                        child: Text(entry.score, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildSummaryCard("Correct", correct.toString(), Colors.green),
                      const SizedBox(width: 12),
                      _buildSummaryCard("Accuracy", responses.isEmpty ? "0%" : "${((correct/responses.length)*100).toInt()}%", Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("QUESTION-BY-QUESTION REVIEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.1)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: responses.length,
                      itemBuilder: (context, idx) {
                        final String qKey = responses.keys.elementAt(idx);
                        final response = responses[qKey];
                        final bool isCorrect = response['isCorrect'] == true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isCorrect ? Colors.green.shade100 : Colors.red.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, 
                                       color: isCorrect ? Colors.green : Colors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Text("Question ${idx + 1}", style: TextStyle(fontWeight: FontWeight.bold, color: isCorrect ? Colors.green.shade800 : Colors.red.shade800)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text("Selected: ${response['answer'] ?? 'N/A'}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              if (!isCorrect)
                                Text("Correct: ${response['correctAnswer'] ?? 'N/A'}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
        ]),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, LeaderboardEntry entry) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Exam?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Delete ${entry.name}\'s attempt?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('RESET', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _db.child('attempts').child(entry.id).remove();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset successful.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset failed.')));
    }
  }
}
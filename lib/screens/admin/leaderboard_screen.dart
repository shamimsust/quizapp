import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../student/result_screen.dart';

class LeaderboardEntry {
  final String id;
  final String userId;
  final String name;
  final String score;
  final String email;
  final String? remarks;

  LeaderboardEntry({
    required this.id,
    required this.userId,
    required this.name,
    required this.score,
    required this.email,
    this.remarks,
  });
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
        title: Text(
          _selectedExamId == null ? 'SELECT EXAM' : 'LEADERBOARD',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 14,
          ),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_selectedExamId != null) {
              setState(() {
                _selectedExamId = null;
                _searchQuery = '';
                _searchController.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _selectedExamId == null ? _buildExamPicker() : _buildRankings(),
    );
  }

  /// Displays only exams that have at least one completed attempt.
  Widget _buildExamPicker() {
    return StreamBuilder(
      stream: _db.child('exams').onValue,
      builder: (context, examSnapshot) {
        if (!examSnapshot.hasData || examSnapshot.data?.snapshot.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final Map<dynamic, dynamic> exams =
            Map<dynamic, dynamic>.from(examSnapshot.data!.snapshot.value as Map);

        return StreamBuilder(
          stream: _db.child('attempts').onValue,
          builder: (context, attemptSnapshot) {
            if (!attemptSnapshot.hasData || attemptSnapshot.data?.snapshot.value == null) {
              return const Center(
                child: Text(
                  "No attempted exams available.",
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              );
            }

            final Map<dynamic, dynamic> attempts =
                Map<dynamic, dynamic>.from(attemptSnapshot.data!.snapshot.value as Map);

            // Collect IDs of exams that have at least one COMPLETED attempt
            final Set<String> attemptedExamIds = {};
            attempts.forEach((key, value) {
              if (value is Map) {
                final Map<String, dynamic> attempt =
                    Map<String, dynamic>.from(value);
                final String? status = attempt['status']?.toString();
                final String? examId = attempt['examId']?.toString();

                if (status == 'completed' && examId != null && examId.isNotEmpty) {
                  attemptedExamIds.add(examId);
                }
              }
            });

            // Filter out exams that do NOT have any completed attempts
            final validExams = exams.entries
                .where((e) => attemptedExamIds.contains(e.key.toString()))
                .toList();

            if (validExams.isEmpty) {
              return const Center(
                child: Text(
                  "No attempted exams available.",
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: validExams.map((e) {
                final Map<String, dynamic> data =
                    Map<String, dynamic>.from(e.value as Map);
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    title: Text(data['title'] ?? 'Untitled Exam',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _selectedExamTitle!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              TextField(
                controller: _searchController,
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search candidate name...',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Expanded(
          child: StreamBuilder(
            stream: _db
                .child('attempts')
                .orderByChild('examId')
                .equalTo(_selectedExamId)
                .onValue,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                return const Center(child: Text("No attempts found."));
              }

              final Map<dynamic, dynamic> data =
                  Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
              final List<LeaderboardEntry> allEntries = [];

              data.forEach((key, value) {
                if (value is Map) {
                  final Map<String, dynamic> attempt =
                      Map<String, dynamic>.from(value);
                  if (attempt['status'] == 'completed') {
                    allEntries.add(LeaderboardEntry(
                      id: key as String,
                      userId: attempt['userId'] ?? '',
                      name: attempt['candidate']?['name'] ?? 'Student',
                      email: attempt['candidate']?['email'] ?? '',
                      score: (attempt['score'] ?? attempt['totalPoints'] ?? '0')
                          .toString(),
                      remarks: attempt['remarks'],
                    ));
                  }
                }
              });

              final List<LeaderboardEntry> filteredEntries = allEntries.where((entry) {
                return entry.name.toLowerCase().contains(_searchQuery) ||
                    entry.email.toLowerCase().contains(_searchQuery);
              }).toList();

              filteredEntries.sort((a, b) {
                final scoreA = double.tryParse(a.score) ?? 0;
                final scoreB = double.tryParse(b.score) ?? 0;
                return scoreB.compareTo(scoreA);
              });

              if (filteredEntries.isEmpty) {
                return const Center(
                  child: Text(
                    "No results matching query.",
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: filteredEntries.length,
                itemBuilder: (context, index) {
                  final LeaderboardEntry entry = filteredEntries[index];
                  final int rank = index + 1;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: rank <= 3
                            ? const Color(0xFF2264D7)
                            : const Color(0xFFF1F5F9),
                        foregroundColor:
                            rank <= 3 ? Colors.white : const Color(0xFF64748B),
                        child: Text(
                          '#$rank',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(entry.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        entry.remarks ?? "Tap to view detailed breakdown",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ResultScreen(attemptId: entry.id),
                          ),
                        );
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.score,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2264D7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 20),
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

  Future<void> _deleteImgBBImages(String attemptId) async {
    try {
      final snapshot = await _db.child('attemptAnswers').child(attemptId).get();
      if (!snapshot.exists || snapshot.value == null) return;

      final Map<dynamic, dynamic> answers =
          Map<dynamic, dynamic>.from(snapshot.value as Map);

      for (var entry in answers.entries) {
        if (entry.value is Map) {
          final Map<String, dynamic> answerData =
              Map<String, dynamic>.from(entry.value as Map);

          final String? deleteUrl = answerData['deleteUrl'];
          if (deleteUrl != null && deleteUrl.isNotEmpty) {
            await http.get(Uri.parse(deleteUrl));
          }
        }
      }
    } catch (e) {
      debugPrint('ImgBB cleanup error: $e');
    }
  }

  Future<void> _confirmReset(BuildContext context, LeaderboardEntry entry) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Attempt & Account?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to delete ${entry.name}\'s attempt, user profile, and uploaded images? This action is permanent.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      // 1. Delete associated ImgBB images from attemptAnswers
      await _deleteImgBBImages(entry.id);

      // 2. Remove attempt and answer database nodes
      await _db.child('attempts').child(entry.id).remove();
      await _db.child('attemptAnswers').child(entry.id).remove();
      await _db.child('results').child(entry.id).remove();

      // 3. Remove user node from Realtime Database
      if (entry.userId.isNotEmpty) {
        await _db.child('users').child(entry.userId).remove();
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attempt and user deleted successfully.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')));
    }
  }
}

/// Helper function to upload images to ImgBB and return both display and delete URLs.
Future<Map<String, String>?> uploadToImgBB(String base64Image, String apiKey) async {
  final Uri uri = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
  final response = await http.post(uri, body: {'image': base64Image});

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body)['data'];
    return {
      'url': data['url'] as String,
      'deleteUrl': data['delete_url'] as String,
    };
  }
  return null;
}
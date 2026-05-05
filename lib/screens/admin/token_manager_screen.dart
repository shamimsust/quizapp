import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/token_service.dart';

class TokenManagerScreen extends StatefulWidget {
  const TokenManagerScreen({super.key});

  @override
  State<TokenManagerScreen> createState() => _TokenManagerScreenState();
}

class _TokenManagerScreenState extends State<TokenManagerScreen> {
  final _tokenService = TokenService();
  final _searchController = TextEditingController();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
  String? _selectedExamId;
  bool _isGenerating = false;
  String _searchQuery = "";
  final Color _primaryBlue = const Color(0xFF2264D7);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('TOKEN MANAGER', 
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildGeneratorCard(),
          _buildSearchBar(),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              // Specific path to avoid "permission_denied at /"
              stream: _db.child('examTokens').onValue, 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text("Error: Access Denied"));
                }

                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return _buildEmptyState();
                }

                final Map<dynamic, dynamic> tokensMap = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
                List<MapEntry<dynamic, dynamic>> tokenEntries = tokensMap.entries.toList();

                tokenEntries.sort((a, b) {
                  final aVal = a.value as Map;
                  final bVal = b.value as Map;
                  final int aTime = aVal['createdAt'] ?? 0;
                  final int bTime = bVal['createdAt'] ?? 0;
                  return bTime.compareTo(aTime);
                });

                if (_searchQuery.isNotEmpty) {
                  tokenEntries = tokenEntries.where((e) {
                    final String key = e.key.toString().toLowerCase();
                    return key.contains(_searchQuery);
                  }).toList();
                }

                return ListView.builder(
                  itemCount: tokenEntries.length,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemBuilder: (context, index) {
                    final String tokenCode = tokenEntries[index].key.toString();
                    final Map tData = tokenEntries[index].value as Map;
                    final String examId = tData['examId'] ?? '';
                    
                    return FutureBuilder<DataSnapshot>(
                      future: _db.child('exams').child(examId).child('title').get(),
                      builder: (context, examSnap) {
                        final String examTitle = examSnap.data?.value?.toString() ?? "Loading...";
                        return _buildTokenTile(tokenCode, examTitle);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratorCard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CREATE ENTRY TOKEN', 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 1.1)),
            const SizedBox(height: 16),
            StreamBuilder<DatabaseEvent>(
              stream: _db.child('exams').onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return const LinearProgressIndicator();
                }
                final Map exams = snapshot.data!.snapshot.value as Map;
                return DropdownButtonFormField<String>(
                  value: _selectedExamId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    hintText: "Select an Exam",
                  ),
                  items: exams.entries.map((e) {
                    final data = e.value as Map;
                    final bool isPublished = data['status'] == 'published';
                    return DropdownMenuItem<String>(
                      value: e.key as String,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(data['title'] ?? 'Untitled', 
                              style: const TextStyle(fontSize: 14, overflow: TextOverflow.ellipsis)),
                          ),
                          _buildStatusBadge(isPublished),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedExamId = val),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: (_isGenerating || _selectedExamId == null) ? null : _handleGenerate,
                child: _isGenerating 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('GENERATE TOKEN', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isPublished) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPublished ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPublished ? "LIVE" : "DRAFT",
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isPublished ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        decoration: InputDecoration(
          hintText: "Search tokens...",
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        ),
      ),
    );
  }

  Widget _buildTokenTile(String code, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        title: Text(code, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
        subtitle: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2264D7))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: Color(0xFF64748B)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token copied!')));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: () => _db.child('examTokens').child(code).remove(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key_off_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No active tokens found", style: TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Future<void> _handleGenerate() async {
    setState(() => _isGenerating = true);
    try {
      await _tokenService.createToken(_selectedExamId!);
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token generated successfully!')));
      }
    } catch (e) {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
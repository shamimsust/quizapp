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
        title: const Text('Token Manager', 
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- GENERATOR SECTION ---
          Padding(
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
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF64748B), letterSpacing: 1.1)),
                  const SizedBox(height: 16),
                  StreamBuilder<DatabaseEvent>(
                    stream: _db.child('exams').onValue,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                        return const LinearProgressIndicator();
                      }
                      
                      final examsMap = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
                      
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
                        items: examsMap.entries.map((e) {
                          final data = Map<String, dynamic>.from(e.value as Map);
                          final bool isDraft = data['status'] != 'published';
                          return DropdownMenuItem(
                            value: e.key as String,
                            child: Row(
                              children: [
                                Expanded(child: Text(data['title'] ?? 'Untitled', overflow: TextOverflow.ellipsis)),
                                if (isDraft)
                                  _buildSmallBadge('DRAFT', Colors.orange)
                                else
                                  _buildSmallBadge('LIVE', Colors.green),
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
          ),

          // --- SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search tokens or Exam IDs...",
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- LIST SECTION ---
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _db.child('examTokens').onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return _buildEmptyState();
                }

                final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
                var tokenEntries = data.entries.toList();

                if (_searchQuery.isNotEmpty) {
                  tokenEntries = tokenEntries.where((e) {
                    final code = e.key.toString().toLowerCase();
                    final examId = (e.value as Map)['examId']?.toString().toLowerCase() ?? "";
                    return code.contains(_searchQuery) || examId.contains(_searchQuery);
                  }).toList();
                }

                return ListView.builder(
                  itemCount: tokenEntries.length,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemBuilder: (context, index) {
                    final code = tokenEntries[index].key.toString();
                    final tData = Map<dynamic, dynamic>.from(tokenEntries[index].value as Map);
                    final String examId = tData['examId'] ?? 'N/A';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        title: Text(code, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFF0F172A))),
                        subtitle: Row(
                          children: [
                            const Icon(Icons.link_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(examId, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF2264D7)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token copied!')));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () => _deleteToken(code),
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
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key_off_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No active tokens found", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _handleGenerate() async {
    setState(() => _isGenerating = true);
    try {
      await _tokenService.createToken(_selectedExamId!);
      if (mounted) setState(() => _isGenerating = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteToken(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Token?"),
        content: Text("Access code '$code' will be permanently revoked."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.child('examTokens').child(code).remove();
    }
  }
}
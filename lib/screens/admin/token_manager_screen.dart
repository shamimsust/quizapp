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
      appBar: AppBar(
        title: const Text('Token Manager', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- GENERATOR SECTION ---
          Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create New Entry Token', 
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    StreamBuilder<Map<String, String>>(
                      stream: _tokenService.watchAllExams(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const LinearProgressIndicator();
                        final exams = snapshot.data!;
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedExamId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(),
                            hintText: "Select an Exam",
                          ),
                          items: exams.entries.map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedExamId = val),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: (_isGenerating || _selectedExamId == null) ? null : _handleGenerate,
                        child: _isGenerating 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Text('Generate Token', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
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
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      }) 
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // --- LIST SECTION ---
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref('examTokens').onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text("No tokens found."));
                }

                final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
                var tokenEntries = data.entries.toList();

                // Apply Search Filter
                if (_searchQuery.isNotEmpty) {
                  tokenEntries = tokenEntries.where((e) {
                    final code = e.key.toString().toLowerCase();
                    final examId = (e.value as Map)['examId']?.toString().toLowerCase() ?? "";
                    return code.contains(_searchQuery) || examId.contains(_searchQuery);
                  }).toList();
                }

                return ListView.builder(
                  itemCount: tokenEntries.length,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemBuilder: (context, index) {
                    final code = tokenEntries[index].key;
                    final tData = Map<dynamic, dynamic>.from(tokenEntries[index].value as Map);
                    final examId = tData['examId'] ?? 'N/A';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ListTile(
                        title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        subtitle: Text("Target Exam: $examId", style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_all, size: 20),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
        content: Text("This will revoke access for code: $code"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Confirm Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseDatabase.instance.ref('examTokens').child(code).remove();
    }
  }
}
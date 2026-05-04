import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  final _db = FirebaseDatabase.instance.ref();
  
  // Navigation State: 'root' is the top level
  List<Map<String, String>> _pathStack = [{'id': 'root', 'name': 'Bank'}];
  
  String get _currentFolderId => _pathStack.last['id']!;

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('QUESTION BANK', 
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_rounded),
            tooltip: 'Export Folder',
            onPressed: () => _exportCurrentFolder(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              // Query items where parentId matches the current folder
              stream: _db.child('questionBank').orderByChild('parentId').equalTo(_currentFolderId).onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<MapEntry<String, dynamic>> folders = [];
                final List<MapEntry<String, dynamic>> questions = [];

                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                  for (var entry in data.entries) {
                    final val = Map<String, dynamic>.from(entry.value);
                    if (val['isFolder'] == true) {
                      folders.add(entry);
                    } else {
                      questions.add(entry);
                    }
                  }
                }

                if (folders.isEmpty && questions.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    if (folders.isNotEmpty) ...[
                      _buildSectionLabel("FOLDERS"),
                      ...folders.map((f) => _buildFolderTile(f.key, f.value['name'])),
                      const SizedBox(height: 20),
                    ],
                    if (questions.isNotEmpty) ...[
                      _buildSectionLabel("QUESTIONS"),
                      ...questions.map((q) => _buildQuestionTile(q.key, q.value)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(primaryBlue),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildBreadcrumbs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pathStack.length,
        separatorBuilder: (_, __) => const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
        itemBuilder: (context, index) {
          final bool isLast = index == _pathStack.length - 1;
          return TextButton(
            onPressed: isLast ? null : () {
              setState(() => _pathStack = _pathStack.sublist(0, index + 1));
            },
            child: Text(
              _pathStack[index]['name']!.toUpperCase(),
              style: TextStyle(
                color: isLast ? const Color(0xFF1E293B) : const Color(0xFF2264D7),
                fontWeight: isLast ? FontWeight.w800 : FontWeight.w500,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFolderTile(String id, String name) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: ListTile(
        leading: const Icon(Icons.folder_rounded, color: Colors.amber),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        onTap: () {
          setState(() => _pathStack.add({'id': id, 'name': name}));
        },
      ),
    );
  }

  Widget _buildQuestionTile(String id, Map<dynamic, dynamic> data) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: ListTile(
        leading: const Icon(Icons.description_outlined, color: Color(0xFF2264D7)),
        title: Text(data['stem'] ?? 'Untitled Question', maxLines: 1, overflow: TextOverflow.ellipsis, 
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text("${data['type']?.toUpperCase()} • ${data['marks']} Points", style: const TextStyle(fontSize: 11)),
        trailing: PopupMenuButton(
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'copy', child: Text('Duplicate')),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
          onSelected: (val) => _handleQuestionAction(val, id, data),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.1)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Folder is Empty", style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFAB(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'addFolder',
          backgroundColor: Colors.white,
          onPressed: _showCreateFolderDialog,
          child: const Icon(Icons.create_new_folder_rounded, color: Colors.amber),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'addQuestion',
          backgroundColor: color,
          onPressed: () => context.push('/admin/exam-builder/new?bankParent=$_currentFolderId'),
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ],
    );
  }

  // --- LOGIC ---

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Folder Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _db.child('questionBank').push().set({
                  'name': controller.text,
                  'parentId': _currentFolderId,
                  'isFolder': true,
                  'createdAt': ServerValue.timestamp,
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('CREATE'),
          )
        ],
      ),
    );
  }

  void _handleQuestionAction(String action, String id, Map data) {
    if (action == 'delete') {
       _db.child('questionBank/$id').remove();
    } else if (action == 'copy') {
      final newData = Map<String, dynamic>.from(data);
      newData['stem'] = "${newData['stem']} (Copy)";
      _db.child('questionBank').push().set(newData);
    }
  }

  void _exportCurrentFolder() {
    // This logic would recursively fetch all questions in this folder 
    // and its children and convert to a JSON string.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preparing JSON export...")));
  }
}
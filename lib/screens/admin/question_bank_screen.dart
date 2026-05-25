import 'dart:convert'; // Added for jsonEncode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard functionality
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
  String get _currentFolderName => _pathStack.last['name']!;

  // --- Clipboard State for Moving Items ---
  String? _cutItemId;
  String? _cutItemName;
  bool _isFolderCut = false;

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('MATH QUESTION BANK', 
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_rounded),
            tooltip: 'Export Folder Content',
            onPressed: () => _exportCurrentFolder(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
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
                      _buildSectionLabel("MATH QUESTIONS"),
                      ...questions.map((q) => _buildQuestionTile(q.key, q.value)),
                    ],
                  ],
                );
              },
            ),
          ),
          // Dynamic clipboard bottom bar panel
          if (_cutItemId != null) _buildPasteStatusBar(primaryBlue),
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
    // Dim the folder if it's currently cut
    final bool isCurrentlyCut = _cutItemId == id;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isCurrentlyCut ? Colors.grey.shade100 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: ListTile(
        leading: Icon(Icons.folder_rounded, color: isCurrentlyCut ? Colors.grey : Colors.amber),
        title: Text(
          name, 
          style: TextStyle(
            fontWeight: FontWeight.w700, 
            fontSize: 15,
            color: isCurrentlyCut ? Colors.grey : Colors.black,
            decoration: isCurrentlyCut ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
          onSelected: (val) => _handleFolderAction(val, id, name),
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'move', child: Row(children: [Icon(Icons.content_cut_rounded, size: 16), SizedBox(width: 8), Text('Move / Cut')])),
            const PopupMenuItem(value: 'rename', child: Text('Rename')),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: isCurrentlyCut ? null : () {
          setState(() => _pathStack.add({'id': id, 'name': name}));
        },
      ),
    );
  }

  Widget _buildQuestionTile(String id, Map<dynamic, dynamic> data) {
    final bool isCurrentlyCut = _cutItemId == id;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isCurrentlyCut ? Colors.grey.shade100 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: ListTile(
        leading: Icon(Icons.functions_rounded, color: isCurrentlyCut ? Colors.grey : const Color(0xFF2264D7)),
        title: Text(
          data['stem'] ?? 'Untitled Math Question', 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis, 
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            fontSize: 14,
            color: isCurrentlyCut ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: Text("${data['type']?.toUpperCase().replaceAll('_', ' ')} • ${data['marks']} Marks", style: const TextStyle(fontSize: 11)),
        onTap: isCurrentlyCut ? null : () => context.push('/admin/exam-builder/$id?bankParent=$_currentFolderId'),
        trailing: PopupMenuButton(
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'move', child: Row(children: [Icon(Icons.content_cut_rounded, size: 16), SizedBox(width: 8), Text('Move / Cut')])),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'copy', child: Text('Duplicate')),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
          onSelected: (val) => _handleQuestionAction(val, id, data),
        ),
      ),
    );
  }

  Widget _buildPasteStatusBar(Color brandColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF2264D7), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Moving "${_cutItemName ?? 'Item'}"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
              ),
            ),
            TextButton(
              onPressed: () => setState(() { _cutItemId = null; _cutItemName = null; }),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: brandColor, foregroundColor: Colors.white),
              onPressed: _executePasteAction,
              icon: const Icon(Icons.folder_special_rounded, size: 16),
              label: const Text('PASTE HERE', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
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

  void _executePasteAction() async {
    if (_cutItemId == null) return;

    if (_isFolderCut && _cutItemId == _currentFolderId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Cannot paste a folder inside itself."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      await _db.child('questionBank/$_cutItemId').update({
        'parentId': _currentFolderId,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved "$_cutItemName" successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to move item."), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() {
        _cutItemId = null;
        _cutItemName = null;
        _isFolderCut = false;
      });
    }
  }

  Future<void> _exportCurrentFolder() async {
    // Show quick status update
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Fetching content from '$_currentFolderName'...")),
    );

    try {
      // Query database for items located inside the current active folder context
      final snapshot = await _db
          .child('questionBank')
          .orderByChild('parentId')
          .equalTo(_currentFolderId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nothing to export! Active folder is completely empty."), backgroundColor: Colors.orange),
        );
        return;
      }

      final rawData = Map<String, dynamic>.from(snapshot.value as Map);
      
      // Filter out system properties and structural folders if you strictly want clean data blocks
      final List<Map<String, dynamic>> cleanList = [];
      
      rawData.forEach((key, value) {
        final Map<String, dynamic> itemMap = Map<String, dynamic>.from(value as Map);
        // Include item system id value in map structure
        itemMap['id'] = key;
        cleanList.add(itemMap);
      });

      // Encode filtered elements into a pretty-printed readable JSON block format
      final String formattedJson = const JsonEncoder.withIndent('  ').convert(cleanList);

      // Copy automatically to local runtime OS clipboard buffer
      await Clipboard.setData(ClipboardData(text: formattedJson));

      if (!mounted) return;

      // Render diagnostic review sheet directly to developer
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.terminal_rounded, color: Color(0xFF2264D7)),
              const SizedBox(width: 8),
              Expanded(child: Text('Export: $_currentFolderName')),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "JSON string configuration data auto-copied to system clipboard context safely!",
                  style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        formattedJson,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2264D7), foregroundColor: Colors.white),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formattedJson));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text("Re-copied to clipboard!")),
                );
              },
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('COPY AGAIN'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export failed: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

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

  void _handleFolderAction(String action, String id, String currentName) {
    if (action == 'move') {
      setState(() {
        _cutItemId = id;
        _cutItemName = currentName;
        _isFolderCut = true;
      });
    } else if (action == 'rename') {
      _showRenameFolderDialog(id, currentName);
    } else if (action == 'delete') {
      _confirmDeleteFolder(id, currentName);
    }
  }

  Future<void> _showRenameFolderDialog(String id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller, 
          decoration: const InputDecoration(hintText: 'New Folder Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty && controller.text != currentName) {
                _db.child('questionBank/$id').update({'name': controller.text});
                Navigator.pop(ctx);
              }
            },
            child: const Text('UPDATE'),
          )
        ],
      ),
    );
  }

  void _confirmDeleteFolder(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Are you sure you want to delete "$name"? Questions inside will need to be re-assigned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              _db.child('questionBank/$id').remove();
              Navigator.pop(ctx);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleQuestionAction(String action, String id, Map data) {
    if (action == 'move') {
      setState(() {
        _cutItemId = id;
        _cutItemName = data['stem'] ?? 'Untitled Question';
        _isFolderCut = false;
      });
    } else if (action == 'edit') {
       context.push('/admin/exam-builder/$id?bankParent=$_currentFolderId');
    } else if (action == 'delete') {
       _db.child('questionBank/$id').remove();
    } else if (action == 'copy') {
      final newData = Map<String, dynamic>.from(data);
      newData['stem'] = "${newData['stem']} (Copy)";
      _db.child('questionBank').push().set(newData);
    }
  }
}
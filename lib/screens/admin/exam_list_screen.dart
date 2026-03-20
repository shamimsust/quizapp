import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';

class ExamListScreen extends StatelessWidget {
  const ExamListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('MANAGE EXAMS', 
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('exams').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: brandBlue));
          }
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return _buildEmptyState(context);
          }

          final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          final exams = data.entries.toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: exams.length,
            itemBuilder: (context, index) {
              final id = exams[index].key;
              final val = Map<String, dynamic>.from(exams[index].value as Map);
              
              final String title = val['title'] ?? 'Untitled Exam';
              final String status = val['status'] ?? 'draft';
              final bool isPublished = status == 'published';
              final bool isManual = val['isManualGrading'] ?? false;
              
              final questionCount = val['questions'] != null 
                  ? (val['questions'] as Map).length 
                  : 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  title: Text(title, 
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Inter', color: Color(0xFF1E293B))),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildBadge(
                            isPublished ? 'PUBLISHED' : 'DRAFT', 
                            isPublished ? Colors.green : Colors.orange
                          ),
                          const SizedBox(width: 8),
                          _buildBadge('$questionCount Qs', brandBlue),
                          if (isManual) ...[
                            const SizedBox(width: 8),
                            _buildBadge('MANUAL', Colors.purple),
                          ]
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) => _handleMenuAction(context, value, id, title, isPublished),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: _MenuLabel(Icons.edit_note_rounded, 'Edit Questions')),
                      const PopupMenuItem(value: 'copy_id', child: _MenuLabel(Icons.copy_rounded, 'Copy Exam ID')),
                      PopupMenuItem(
                        value: 'toggle_status', 
                        child: _MenuLabel(
                          isPublished ? Icons.visibility_off_rounded : Icons.visibility_rounded, 
                          isPublished ? 'Set as Draft' : 'Publish Exam'
                        )
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: _MenuLabel(Icons.delete_outline_rounded, 'Delete', isDestructive: true)),
                    ],
                  ),
                  onTap: () => context.push('/admin/exam-builder/questions/$id'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: brandBlue,
        onPressed: () => context.push('/admin/exam-builder'),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('CREATE EXAM', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.1, fontFamily: 'Inter')),
      ),
    );
  }

  // --- Helper UI Widgets ---

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, 
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'Inter')),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          const Text("No Exams Created Yet", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF64748B), fontFamily: 'Inter')),
          const SizedBox(height: 8),
          const Text("Start by building your first tournament exam.", 
            style: TextStyle(fontSize: 14, color: Colors.blueGrey)),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2264D7), foregroundColor: Colors.white),
            onPressed: () => context.push('/admin/exam-builder'),
            child: const Text("Build New Exam"),
          ),
        ],
      ),
    );
  }

  // --- Logic Handlers ---

  void _handleMenuAction(BuildContext context, String action, String id, String title, bool isPublished) {
    switch (action) {
      case 'edit':
        context.push('/admin/exam-builder/questions/$id');
        break;
      case 'copy_id':
        Clipboard.setData(ClipboardData(text: id));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID copied to clipboard')));
        break;
      case 'toggle_status':
        FirebaseDatabase.instance.ref('exams/$id').update({
          'status': isPublished ? 'draft' : 'published'
        });
        break;
      case 'delete':
        _confirmDeleteExam(context, id, title);
        break;
    }
  }

  Future<void> _confirmDeleteExam(BuildContext context, String id, String title) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exam?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$title"? All associated data and questions will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE PERMANENTLY', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseDatabase.instance.ref('exams/$id').remove();
    }
  }
}

class _MenuLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  const _MenuLabel(this.icon, this.label, {this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : const Color(0xFF475569);
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
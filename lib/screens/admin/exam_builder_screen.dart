import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';

class ExamBuilderScreen extends ConsumerStatefulWidget {
  final String? examId;
  const ExamBuilderScreen({super.key, this.examId});

  @override
  ConsumerState<ExamBuilderScreen> createState() => _ExamBuilderScreenState();
}

class _ExamBuilderScreenState extends ConsumerState<ExamBuilderScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _duration = TextEditingController(text: '45');
  
  bool _containsWritten = false;
  String? _examId; 
  bool _isSaving = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.examId != null) {
      _examId = widget.examId;
      _loadExistingExam();
    }
  }

  Future<void> _loadExistingExam() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseDatabase.instance.ref('exams/$_examId').get();
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        _title.text = data['title'] ?? '';
        _desc.text = data['description'] ?? '';
        final int ms = data['durationMs'] ?? 2700000;
        _duration.text = (ms ~/ 60000).toString();
        _containsWritten = data['containsWritten'] ?? false;
      }
    } catch (e) {
      debugPrint("Error loading exam: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_examId == null ? 'Create New Quiz' : 'Edit Quiz Details', 
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: brandBlue))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_examId != null && widget.examId == null) _buildSuccessBanner(),

            _buildSectionTitle('Basic Information'),
            const SizedBox(height: 12),
            _buildTextField(_title, 'Quiz Title', Icons.edit),
            const SizedBox(height: 16),
            _buildTextField(_desc, 'Instructions', Icons.info_outline, maxLines: 2),
            const SizedBox(height: 16),
            _buildTextField(_duration, 'Duration (minutes)', Icons.timer_outlined, isNumber: true),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Settings'),
            const SizedBox(height: 12),
            
            SwitchListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              value: _containsWritten,
              onChanged: (v) => setState(() => _containsWritten = v),
              title: const Text('Allow Written Responses', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Students can type long-form answers.', style: TextStyle(fontSize: 12)),
              activeThumbColor: brandBlue,
            ),

            const SizedBox(height: 40),
            _buildActionButtons(brandBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: Icon(icon),
        filled: true, 
        fillColor: Colors.white, 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.5));
  }

  Widget _buildActionButtons(Color brandBlue) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandBlue, 
              padding: const EdgeInsets.symmetric(vertical: 16), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_examId == null ? 'Save Quiz' : 'Update Quiz', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        if (_examId != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800, 
                padding: const EdgeInsets.symmetric(vertical: 16), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () => context.go('/admin/exam-builder/questions/$_examId'),
              child: const Text('Edit Questions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]
      ],
    );
  }

  Future<void> _handleSave() async {
    if (_title.text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final updates = {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'durationMs': (int.tryParse(_duration.text.trim()) ?? 45) * 60000,
        'containsWritten': _containsWritten,
        'updatedAt': ServerValue.timestamp,
      };

      if (_examId == null) {
        final ref = FirebaseDatabase.instance.ref('exams').push();
        await ref.set(updates);
        _examId = ref.key;
      } else {
        await FirebaseDatabase.instance.ref('exams/$_examId').update(updates);
      }
      
      setState(() => _isSaving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz saved!')));
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
      child: SelectableText('Success! Quiz ID: $_examId', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
    );
  }
}
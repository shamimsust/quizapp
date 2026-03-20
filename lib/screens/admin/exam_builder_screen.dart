import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/exam.dart';
import '../../services/exam_service.dart';

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
  
  // NEW: Grading States
  bool _containsWritten = false;
  bool _isManualGrading = false; // Toggle for Manual vs Auto
  
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
        _isManualGrading = data['isManualGrading'] ?? false; // Load grading mode
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
        title: Text(_examId == null ? 'Create New Quiz' : 'Edit Quiz Metadata', 
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_examId != null && widget.examId == null) _buildSuccessBanner(),

            _buildSectionTitle('Basic Information'),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: 'Quiz Title', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _desc,
              decoration: InputDecoration(labelText: 'Description / Instructions', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _duration,
              decoration: InputDecoration(labelText: 'Duration (minutes)', prefixIcon: const Icon(Icons.timer_outlined), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Grading & Settings'),
            const SizedBox(height: 12),

            // --- NEW: GRADING MODE SELECTION ---
            _buildGradingOption(
              title: 'Auto-Graded (Points)',
              subtitle: 'System checks MCQs instantly. Best for objective tests.',
              icon: Icons.bolt,
              isSelected: !_isManualGrading,
              onTap: () => setState(() => _isManualGrading = false),
              brandBlue: brandBlue,
            ),
            const SizedBox(height: 12),
            _buildGradingOption(
              title: 'Manual Review (Ranks/Points)',
              subtitle: 'Teacher reviews answers and assigns Ranks (1st, 2nd) or final scores.',
              icon: Icons.rate_review_outlined,
              isSelected: _isManualGrading,
              onTap: () => setState(() => _isManualGrading = true),
              brandBlue: brandBlue,
            ),

            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _containsWritten,
              onChanged: (v) => setState(() => _containsWritten = v),
              title: const Text('Allow Written/LaTeX Responses', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Students can type long-form answers and math.', style: TextStyle(fontSize: 12)),
              activeColor: brandBlue,
            ),

            const SizedBox(height: 40),
            _buildActionButtons(brandBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey));
  }

  Widget _buildGradingOption({required String title, required String subtitle, required IconData icon, required bool isSelected, required VoidCallback onTap, required Color brandBlue}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? brandBlue.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? brandBlue : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? brandBlue : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? brandBlue : Colors.black87)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: brandBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
      child: SelectableText('Success! Quiz ID: $_examId', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
    );
  }

  Widget _buildActionButtons(Color brandBlue) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brandBlue, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_examId == null ? 'Save Metadata' : 'Update Metadata', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        if (_examId != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
        'isManualGrading': _isManualGrading, // Save the selected mode
        'updatedAt': ServerValue.timestamp,
      };

      String id;
      if (_examId == null) {
        final ref = FirebaseDatabase.instance.ref('exams').push();
        await ref.set(updates);
        id = ref.key!;
      } else {
        await FirebaseDatabase.instance.ref('exams/$_examId').update(updates);
        id = _examId!;
      }
      
      setState(() { _examId = id; _isSaving = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Metadata saved!')));
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }
}
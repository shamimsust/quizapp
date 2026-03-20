import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart'; // Added for direct loading
import '../../models/exam.dart';
import '../../services/exam_service.dart';

class ExamBuilderScreen extends ConsumerStatefulWidget {
  final String? examId; // Added to handle editing
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
    // If an ID was passed in the constructor, load it immediately
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
        // Convert ms back to minutes for the controller
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
      appBar: AppBar(
        title: Text(_examId == null ? 'Create New Exam' : 'Edit Exam Metadata', 
          style: const TextStyle(fontFamily: 'Inter')),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_examId != null && widget.examId == null) // Show success only on fresh create
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: SelectableText(
                  'Success! Use this ID for tokens: $_examId',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),

            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Exam Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description (Instructions)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _duration,
              decoration: const InputDecoration(labelText: 'Duration (minutes)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _containsWritten,
              onChanged: (v) => setState(() => _containsWritten = v),
              title: const Text('Includes Written/LaTeX Questions', style: TextStyle(fontSize: 14)),
              activeThumbColor: brandBlue,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: brandBlue),
                    onPressed: _isSaving ? null : _handleSave,
                    child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_examId == null ? 'Save Exam Metadata' : 'Update Metadata', 
                          style: const TextStyle(color: Colors.white)),
                  ),
                ),
                if (_examId != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
                      onPressed: () => context.go('/admin/exam-builder/questions/$_examId'),
                      child: const Text('Add Questions', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_title.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final exam = Exam(
        id: _examId ?? '', 
        title: _title.text.trim(),
        description: _desc.text.trim(),
        durationMs: (int.tryParse(_duration.text.trim()) ?? 45) * 60000,
        containsWritten: _containsWritten,
      );

      String id;
      if (_examId == null) {
        // Create new
        id = await ExamService().createExam(exam);
      } else {
        // Update existing
        await FirebaseDatabase.instance.ref('exams/$_examId').update({
          'title': exam.title,
          'description': exam.description,
          'durationMs': exam.durationMs,
          'containsWritten': exam.containsWritten,
          'updatedAt': ServerValue.timestamp,
        });
        id = _examId!;
      }
      
      setState(() {
        _examId = id;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_examId == widget.examId ? 'Changes updated!' : 'Meta saved. Now add questions!')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
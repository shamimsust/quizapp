import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../widgets/latex_text.dart';

class QuestionEditorScreen extends StatefulWidget {
  final String examId;
  const QuestionEditorScreen({super.key, required this.examId});

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  final _scrollController = ScrollController();
  
  // Form State
  String _type = 'mcq_single';
  final _stemController = TextEditingController();
  final _marksController = TextEditingController(text: '1');
  bool _isSaving = false;
  String? _editingQuestionId;

  // MCQ Options State
  final Map<String, TextEditingController> _optionControllers = {
    'A': TextEditingController(),
    'B': TextEditingController(),
    'C': TextEditingController(),
    'D': TextEditingController(),
  };
  final Set<String> _correctOptions = {};

  @override
  void initState() {
    super.initState();
    _stemController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _stemController.dispose();
    _marksController.dispose();
    _scrollController.dispose();
    for (var c in _optionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // --- FORM LOGIC ---

  void _prepareEdit(String qId, Map<String, dynamic> data) {
    setState(() {
      _editingQuestionId = qId;
      _type = data['type'] ?? 'mcq_single';
      _stemController.text = data['stem'] ?? '';
      _marksController.text = (data['marks'] ?? 1).toString();
      _correctOptions.clear();
      
      if (data['correctOptions'] != null) {
        _correctOptions.addAll(List<String>.from(data['correctOptions']));
      }

      if (data['options'] != null) {
        final List<dynamic> opts = data['options'];
        for (var opt in opts) {
          final id = opt['id'];
          if (_optionControllers.containsKey(id)) {
            _optionControllers[id]!.text = opt['text'] ?? '';
          }
        }
      }
    });
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  void _clearForm() {
    setState(() {
      _editingQuestionId = null;
      _stemController.clear();
      _marksController.text = '1';
      _correctOptions.clear();
      for (var c in _optionControllers.values) {
        c.clear();
      }
    });
  }

  // --- DATABASE OPERATIONS ---

  Future<void> _saveQuestion() async {
    if (_stemController.text.trim().isEmpty) {
      _showSnackBar('Question stem is required', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final marks = int.tryParse(_marksController.text) ?? 1;
      final qMap = {
        'type': _type,
        'stem': _stemController.text.trim(),
        'marks': marks,
        if (_type.startsWith('mcq')) 
          'options': _optionControllers.entries.map((e) => {'id': e.key, 'text': e.value.text.trim()}).toList(),
        if (_type.startsWith('mcq')) 
          'correctOptions': _correctOptions.toList(),
        if (_type == 'written') 'expectsLatex': true,
      };

      final ref = FirebaseDatabase.instance.ref('exams/${widget.examId}/questions');
      
      if (_editingQuestionId != null) {
        await ref.child(_editingQuestionId!).update(qMap);
      } else {
        await ref.push().set(qMap);
      }
      
      _clearForm();
      _showSnackBar('Question saved successfully!');
    } catch (e) {
      _showSnackBar('Error saving: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- BATCH IMPORT ENGINE ---

  void _showBatchImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batch Import (MCQ)', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Format per line:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const Text('Stem | A | B | C | D | CorrectID | Marks', 
              style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontFamily: 'monospace')),
            const SizedBox(height: 16),
            TextField(
              controller: controller, 
              maxLines: 8, 
              decoration: InputDecoration(
                hintText: 'Gravity is... | A | B | C | D | A | 1', 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                fillColor: const Color(0xFFF1F5F9),
                filled: true,
              )
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2264D7)),
            onPressed: () { _processBatch(controller.text); Navigator.pop(context); }, 
            child: const Text('IMPORT ALL', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _processBatch(String text) async {
    final lines = text.split('\n').where((l) => l.contains('|')).toList();
    int count = 0;
    for (var line in lines) {
      final p = line.split('|').map((e) => e.trim()).toList();
      if (p.length >= 6) {
        await FirebaseDatabase.instance.ref('exams/${widget.examId}/questions').push().set({
          'type': 'mcq_single',
          'stem': p[0],
          'options': [{'id': 'A', 'text': p[1]}, {'id': 'B', 'text': p[2]}, {'id': 'C', 'text': p[3]}, {'id': 'D', 'text': p[4]}],
          'correctOptions': [p[5].toUpperCase()],
          'marks': p.length > 6 ? (int.tryParse(p[6]) ?? 1) : 1,
        });
        count++;
      }
    }
    _showSnackBar('Imported $count questions!');
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        // Added back button navigation
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_editingQuestionId == null ? 'QUESTION BUILDER' : 'EDITING QUESTION', 
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.auto_fix_high_rounded), tooltip: 'Batch Import', onPressed: _showBatchImportDialog),
          if (_editingQuestionId != null)
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: _clearForm, tooltip: 'Cancel Edit'),
          const SizedBox(width: 8),
        ],
      ),
      // Floating button to finalize and return to dashboard
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
        label: const Text("FINISH & EXIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          children: [
            _buildMainForm(brandBlue),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Divider(color: Color(0xFFE2E8F0)),
            ),
            _buildExistingQuestionsList(brandBlue),
            const SizedBox(height: 120), // Added extra spacing for the FAB
          ],
        ),
      ),
    );
  }

  Widget _buildMainForm(Color brandBlue) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('QUESTION SETTINGS'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: _inputDecoration('Type'),
            onChanged: (v) => setState(() { _type = v!; _correctOptions.clear(); }),
            items: const [
              DropdownMenuItem(value: 'mcq_single', child: Text('MCQ (Single Choice)')),
              DropdownMenuItem(value: 'mcq_multi', child: Text('MCQ (Multiple Choice)')),
              DropdownMenuItem(value: 'written', child: Text('Written / Theory Response')),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _stemController,
            maxLines: 4,
            decoration: _inputDecoration('Question Stem (Supports LaTeX: \$x^2\$)'),
          ),
          const SizedBox(height: 12),
          _buildLivePreview(brandBlue),
          const SizedBox(height: 20),
          TextField(
            controller: _marksController, 
            decoration: _inputDecoration('Marks Awarded'),
            keyboardType: TextInputType.number
          ),
          
          if (_type.startsWith('mcq')) ...[
            const SizedBox(height: 32),
            _buildLabel('OPTIONS & ANSWERS'),
            const SizedBox(height: 16),
            ...['A', 'B', 'C', 'D'].map((id) => _buildOptionRow(id, brandBlue)),
          ],

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity, height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _editingQuestionId == null ? brandBlue : Colors.orange.shade700, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _isSaving ? null : _saveQuestion,
              child: _isSaving 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                : Text(_editingQuestionId == null ? 'ADD TO EXAM' : 'UPDATE QUESTION', 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(String id, Color brandBlue) {
    final isSelected = _correctOptions.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              if (_type == 'mcq_single') _correctOptions.clear();
              isSelected ? _correctOptions.remove(id) : _correctOptions.add(id);
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isSelected ? brandBlue : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(id, style: TextStyle(color: isSelected ? Colors.white : brandBlue, fontWeight: FontWeight.bold))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _optionControllers[id],
            decoration: InputDecoration(
              hintText: 'Enter choice $id...',
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              border: InputBorder.none,
            ),
          )),
          Checkbox(
            activeColor: brandBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            value: isSelected,
            onChanged: (v) => setState(() {
              if (v == true) { if (_type == 'mcq_single') _correctOptions.clear(); _correctOptions.add(id); }
              else { _correctOptions.remove(id); }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview(Color brandBlue) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: brandBlue.withValues(alpha: 0.1))
      ),
      child: _stemController.text.isEmpty 
        ? const Text(
            'Live preview will appear here...', 
            style: TextStyle(
              color: Color(0xFF94A3B8), 
              fontSize: 13, 
              fontStyle: FontStyle.italic
            )
          ) 
        : LatexText(_stemController.text, size: 16),
    );
  }

  Widget _buildExistingQuestionsList(Color brandBlue) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('exams/${widget.examId}/questions').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text("No questions added to this exam yet.", style: TextStyle(color: Colors.blueGrey)));
        }
        
        final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('CURRENT QUESTIONS (${data.length})'),
            const SizedBox(height: 16),
            ...data.entries.map((e) {
              final q = Map<String, dynamic>.from(e.value as Map);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  title: LatexText(q['stem'] ?? '', size: 14),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("${q['type'].toString().toUpperCase()} • MARKS: ${q['marks']}", 
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.orange, size: 20), onPressed: () => _prepareEdit(e.key, q)),
                      IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _deleteQuestion(e.key)),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _deleteQuestion(String qId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question?'),
        content: const Text('This will permanently remove this question from the exam pool.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseDatabase.instance.ref('exams/${widget.examId}/questions/$qId').remove();
      if (_editingQuestionId == qId) _clearForm();
    }
  }

  // --- UI Helpers ---
  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.2));
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2264D7), width: 1.5)),
    );
  }
}
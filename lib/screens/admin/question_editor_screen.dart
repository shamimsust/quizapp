import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/question.dart';
import '../../services/exam_service.dart';
import '../../widgets/latex_text.dart';

class QuestionEditorScreen extends StatefulWidget {
  final String examId;
  const QuestionEditorScreen({super.key, required this.examId});

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  String _type = 'mcq_single';
  final _stem = TextEditingController();
  final _marks = TextEditingController(text: '1');
  bool _isSaving = false;

  final _options = <Map<String, String>>[
    {'id': 'A', 'text': ''},
    {'id': 'B', 'text': ''},
    {'id': 'C', 'text': ''},
    {'id': 'D', 'text': ''},
  ];
  final _correct = <String>{};

  @override
  void initState() {
    super.initState();
    // Re-render preview whenever stem or options change
    _stem.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _stem.dispose();
    _marks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Question Editor', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => context.go('/admin-dashboard'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TYPE SELECTION
            DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(
                labelText: 'Question Type',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() {
                _type = v!;
                _correct.clear();
              }),
              items: const [
                DropdownMenuItem(value: 'mcq_single', child: Text('MCQ (Single Choice)')),
                DropdownMenuItem(value: 'mcq_multi', child: Text('MCQ (Multiple Choice)')),
                DropdownMenuItem(value: 'written', child: Text('Written / Theory')),
              ],
            ),
            const SizedBox(height: 24),
            
            // QUESTION INPUT
            const Text('Question Stem (Supports Bangla + \$Math\$)', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            TextField(
              controller: _stem,
              decoration: InputDecoration(
                // FIXED: Escaped the $ symbols with \ to avoid the 'Undefined name x' error
                hintText: 'উদা: পিতার বয়স \$x\$ হলে...', 
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 4,
            ),
            
            // LIVE PREVIEW BOX
            const SizedBox(height: 16),
            const Text('Live Preview:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryBlue.withOpacity(0.3)),
              ),
              child: _stem.text.isEmpty
                  ? const Text('Your question will appear here...', style: TextStyle(color: Colors.grey))
                  : LatexText(_stem.text, size: 18),
            ),

            const SizedBox(height: 24),
            TextField(
              controller: _marks,
              decoration: InputDecoration(
                labelText: 'Marks for this question',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
            ),

            if (_type.startsWith('mcq')) ...[
              const SizedBox(height: 32),
              const Text('Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ..._options.map((opt) {
                final id = opt['id']!;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(radius: 16, backgroundColor: primaryBlue, child: Text(id, style: const TextStyle(color: Colors.white, fontSize: 12))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => opt['text'] = v),
                              decoration: const InputDecoration(
                                hintText: 'Option Text or \$Math\$',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          Checkbox(
                            activeColor: primaryBlue,
                            value: _correct.contains(id),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  if (_type == 'mcq_single') _correct.clear();
                                  _correct.add(id);
                                } else {
                                  _correct.remove(id);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      // Option Preview
                      if (opt['text']!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 44),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: LatexText(opt['text']!, size: 14, color: Colors.blueGrey),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _saveQuestion,
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save & Add Next Question', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 100), 
          ],
        ),
      ),
    );
  }

  Future<void> _saveQuestion() async {
    final stemText = _stem.text.trim();
    if (stemText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stem cannot be empty.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final marks = int.tryParse(_marks.text.trim()) ?? 1;

      if (_type.startsWith('mcq')) {
        if (_correct.isEmpty) throw 'Select a correct answer.';
        
        final q = Question(
          id: '',
          type: _type,
          stem: stemText,
          options: _options.map((e) => OptionItem(id: e['id']!, text: e['text'] ?? '')).toList(),
          correctOptions: _correct.toList(),
          marks: marks,
        );
        await ExamService().addQuestion(widget.examId, q);
      } else {
        final q = Question(
          id: '',
          type: 'written',
          stem: stemText,
          marks: marks,
          expectsLatex: true,
        );
        await ExamService().addQuestion(widget.examId, q);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Question Saved!'), backgroundColor: Colors.green));
        _stem.clear();
        _marks.text = '1';
        for (var o in _options) { o['text'] = ''; }
        _correct.clear();
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
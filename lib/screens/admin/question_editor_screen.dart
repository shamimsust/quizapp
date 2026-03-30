import 'dart:convert'; // For base64 and jsonDecode
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http; // Make sure to add http to pubspec.yaml
import 'package:image_picker/image_picker.dart';
import '../../widgets/latex_text.dart';

class QuestionEditorScreen extends StatefulWidget {
  final String examId;
  const QuestionEditorScreen({super.key, required this.examId});

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  final _scrollController = ScrollController();
  final _db = FirebaseDatabase.instance.ref();
  
  // ImgBB API Configuration
  final String _imgBBKey = "bd9c2f7a1ff71a3e72aead970348d485";
  
  static const Color brandBlue = Color(0xFF2264D7);
  
  String _type = 'mcq_single';
  final _stemController = TextEditingController();
  final _marksController = TextEditingController(text: '1');
  bool _isSaving = false;
  bool _isUploading = false;
  String? _editingQuestionId;
  String? _imageUrl;

  final Map<String, TextEditingController> _optionControllers = {
    'A': TextEditingController(), 'B': TextEditingController(),
    'C': TextEditingController(), 'D': TextEditingController(),
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
    for (final c in _optionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // --- IMGBB UPLOAD LOGIC ---
  Future<void> _pickAndUploadImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery, 
      imageQuality: 75
    );
    
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload'));
      request.fields['key'] = _imgBBKey;
      request.fields['image'] = base64Image;

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200) {
        setState(() {
          _imageUrl = jsonResponse['data']['url'];
        });
        _showSnackBar('Image uploaded to ImgBB!');
      } else {
        throw Exception(jsonResponse['error']['message'] ?? 'Upload failed');
      }
    } catch (e) {
      _showSnackBar('Upload Error: $e', isError: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // --- REORDER LOGIC ---
  Future<void> _updateOrder(List<MapEntry<String, dynamic>> list) async {
    final Map<String, dynamic> updates = {};
    for (int i = 0; i < list.length; i++) {
      updates['exams/${widget.examId}/questions/${list[i].key}/order'] = i;
    }
    await _db.update(updates);
  }

  // --- CLONE LOGIC ---
  Future<void> _cloneQuestion(Map<String, dynamic> data) async {
    setState(() => _isSaving = true);
    try {
      final clonedData = Map<String, dynamic>.from(data);
      clonedData['order'] = DateTime.now().millisecondsSinceEpoch;
      await _db.child('exams/${widget.examId}/questions').push().set(clonedData);
      _showSnackBar('Question cloned successfully!');
    } catch (e) {
      _showSnackBar('Cloning failed', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- DELETE LOGIC ---
  Future<void> _deleteQuestion(String qId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Content?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('DELETE', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.child('exams/${widget.examId}/questions/$qId').remove();
        if (_editingQuestionId == qId) {
          _clearForm();
        }
        _showSnackBar('Deleted successfully');
      } catch (e) {
        _showSnackBar('Delete failed', isError: true);
      }
    }
  }

  // --- DATABASE OPERATIONS ---
  Future<void> _saveQuestion() async {
    final stemText = _stemController.text.trim();
    if (stemText.isEmpty) {
      return _showSnackBar('Content is required', isError: true);
    }

    setState(() => _isSaving = true);
    try {
      final marks = _type == 'info_block' ? 0 : (int.tryParse(_marksController.text) ?? 1);
      final qMap = {
        'type': _type,
        'stem': stemText,
        'marks': marks,
        if (_imageUrl != null) 'imageUrl': _imageUrl,
        if (_type.startsWith('mcq')) 
          'options': _optionControllers.entries.map((e) => {'id': e.key, 'text': e.value.text.trim()}).toList(),
        if (_type.startsWith('mcq')) 
          'correctOptions': _correctOptions.toList(),
        if (_editingQuestionId == null) 'order': DateTime.now().millisecondsSinceEpoch,
      };

      final ref = _db.child('exams/${widget.examId}/questions');
      if (_editingQuestionId != null) {
        await ref.child(_editingQuestionId!).update(qMap);
      } else {
        await ref.push().set(qMap);
      }
      _clearForm();
      _showSnackBar('Saved successfully!');
    } catch (e) {
      _showSnackBar('Error saving', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_editingQuestionId == null ? 'BUILDER' : 'EDITING', 
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        actions: [
          if (_editingQuestionId != null) 
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: _clearForm),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildMainForm(),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text("DRAG HANDLES TO REORDER", 
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.2)),
            ),
          ),
          _buildExistingQuestionsList(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildExistingQuestionsList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _db.child('exams/${widget.examId}/questions').orderByChild('order').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const SliverToBoxAdapter(child: Center(child: Text("No content yet")));
        }
        
        final Map<dynamic, dynamic> rawData = snapshot.data!.snapshot.value as Map;
        final list = rawData.entries.map((e) => MapEntry(e.key.toString(), e.value)).toList()
          ..sort((a, b) => (a.value['order'] ?? 0).compareTo(b.value['order'] ?? 0));
        
        return SliverReorderableList(
          itemCount: list.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = list.removeAt(oldIndex);
              list.insert(newIndex, item);
              _updateOrder(list);
            });
          },
          itemBuilder: (context, index) {
            final e = list[index];
            final q = Map<String, dynamic>.from(e.value as Map);
            final bool isInfo = q['type'] == 'info_block';

            return ReorderableDelayedDragStartListener(
              key: ValueKey(e.key),
              index: index,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 16, right: 8),
                  leading: q['imageUrl'] != null 
                      ? const Icon(Icons.image, color: Colors.blue, size: 20) 
                      : Icon(isInfo ? Icons.info_outline : Icons.help_outline, size: 20),
                  title: Text(q['stem'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(isInfo ? 'INFO BLOCK' : 'MARKS: ${q['marks']}', 
                    style: const TextStyle(fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.blueGrey), 
                        onPressed: () => _cloneQuestion(q),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: brandBlue), 
                        onPressed: () => _prepareEdit(e.key, q),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent), 
                        onPressed: () => _deleteQuestion(e.key),
                      ),
                      const Icon(Icons.drag_indicator_rounded, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMainForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: const Color(0xFFE2E8F0))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('CONTENT TYPE'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: _inputDecoration('Type'),
            onChanged: (v) => setState(() { 
              _type = v!; 
              _marksController.text = _type == 'info_block' ? '0' : '1';
            }),
            items: const [
              DropdownMenuItem(value: 'mcq_single', child: Text('MCQ (Single Choice)')),
              DropdownMenuItem(value: 'mcq_multi', child: Text('MCQ (Multiple Choice)')),
              DropdownMenuItem(value: 'written', child: Text('Written Response')),
              DropdownMenuItem(value: 'info_block', child: Text('Info/Stem Block')),
            ],
          ),
          const SizedBox(height: 20),
          _buildImageSection(),
          const SizedBox(height: 20),
          TextField(controller: _stemController, maxLines: 3, decoration: _inputDecoration('Stem Content')),
          const SizedBox(height: 12),
          _buildLivePreview(),
          if (_type != 'info_block') ...[
            const SizedBox(height: 20),
            TextField(controller: _marksController, decoration: _inputDecoration('Marks'), keyboardType: TextInputType.number),
          ],
          if (_type.startsWith('mcq')) ...[
            const SizedBox(height: 32),
            ...['A', 'B', 'C', 'D'].map((id) => _buildOptionRow(id)),
          ],
          const SizedBox(height: 32),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    if (_imageUrl != null) {
      return Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover)),
        Positioned(right: 8, top: 8, child: CircleAvatar(backgroundColor: Colors.red, child: IconButton(icon: const Icon(Icons.delete, color: Colors.white), onPressed: () => setState(() => _imageUrl = null)))),
      ]);
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
      onPressed: _isUploading ? null : _pickAndUploadImage,
      icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_a_photo_outlined),
      label: Text(_isUploading ? 'UPLOADING TO IMGBB...' : 'ADD IMAGE'),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: brandBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      onPressed: _isSaving ? null : _saveQuestion,
      child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE CONTENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ));
  }

  Widget _buildOptionRow(String id) {
    final isSelected = _correctOptions.contains(id);
    return Row(children: [
      Checkbox(activeColor: brandBlue, value: isSelected, onChanged: (v) => setState(() {
        if (v == true && _type == 'mcq_single') {
          _correctOptions.clear();
        }
        v == true ? _correctOptions.add(id) : _correctOptions.remove(id);
      })),
      Expanded(child: TextField(controller: _optionControllers[id], decoration: InputDecoration(hintText: 'Option $id', border: InputBorder.none))),
    ]);
  }

  Widget _buildLivePreview() => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC), 
      borderRadius: BorderRadius.circular(12), 
      border: Border.all(color: brandBlue.withValues(alpha: 0.1))
    ),
    child: _stemController.text.isEmpty ? const Text('Preview...', style: TextStyle(color: Colors.grey, fontSize: 12)) : LatexText(_stemController.text, size: 14),
  );

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1));

  InputDecoration _inputDecoration(String label) => InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))));

  void _prepareEdit(String qId, Map<String, dynamic> data) {
    setState(() {
      _editingQuestionId = qId; _type = data['type'] ?? 'mcq_single';
      _stemController.text = data['stem'] ?? ''; _marksController.text = (data['marks'] ?? 1).toString();
      _imageUrl = data['imageUrl']; _correctOptions.clear();
      if (data['correctOptions'] != null) {
        _correctOptions.addAll(List<String>.from(data['correctOptions']));
      }
      for (var c in _optionControllers.values) {
        c.clear();
      }
      if (data['options'] != null) {
        for (final opt in data['options']) {
          if (_optionControllers.containsKey(opt['id'])) {
            _optionControllers[opt['id']]!.text = opt['text'] ?? '';
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
      _imageUrl = null; 
      _correctOptions.clear(); 
      for (final c in _optionControllers.values) {
        c.clear();
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green.shade600));
  }
}
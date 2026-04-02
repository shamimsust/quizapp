import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
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

  final String _imgBBKey = "bd9c2f7a1ff71a3e72aead970348d485";
  static const Color brandBlue = Color(0xFF2264D7);

  String _type = 'mcq_single';
  final _stemController = TextEditingController();
  final _marksController = TextEditingController(text: '1');
  final _bulkInputController = TextEditingController(); 

  bool _isSaving = false;
  bool _isUploading = false;
  String? _editingQuestionId;
  String? _imageUrl;

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
    _bulkInputController.dispose();
    _scrollController.dispose();
    for (final c in _optionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // --- IMGBB UPLOAD LOGIC ---
  Future<void> _pickAndUploadImage() async {
    // 1. Trigger the picker as the absolute first step (User Gesture Requirement)
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 75
    );

    if (image == null) return;

    // 2. Start UI loading after the picker returns
    setState(() => _isUploading = true);
    try {
      // 3. Use readAsBytes() (Compatible with Web/Mobile) instead of File(image.path)
      final Uint8List bytes = await image.readAsBytes(); 
      final String base64Image = base64Encode(bytes);
      
      final http.MultipartRequest request = http.MultipartRequest(
          'POST', Uri.parse('https://api.imgbb.com/1/upload'));
      request.fields['key'] = _imgBBKey;
      request.fields['image'] = base64Image;

      final http.StreamedResponse response = await request.send();
      final String responseData = await response.stream.bytesToString();
      final Map<String, dynamic> jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => _imageUrl = jsonResponse['data']['url']);
        }
        _showSnackBar('Image uploaded to ImgBB!');
      } else {
        throw Exception(jsonResponse['error']['message'] ?? 'Upload failed');
      }
    } catch (e) {
      _showSnackBar('Upload Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- AUTO-DETECT BULK CREATION ---
  Future<void> _processBulkQuestions() async {
    final String rawInput = _bulkInputController.text.trim();
    if (rawInput.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final ref = _db.child('exams/${widget.examId}/questions');
      int baseOrder = DateTime.now().millisecondsSinceEpoch;
      final lines = rawInput.split('\n');
      int count = 0;

      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final parts = trimmed.split('|').map((e) => e.trim()).toList();
        final Map<String, dynamic> qData = {'order': baseOrder++};

        if (parts.length >= 7) {
          qData.addAll({
            'type': 'mcq_single',
            'stem': parts[0],
            'options': [
              {'id': 'A', 'text': parts[1]},
              {'id': 'B', 'text': parts[2]},
              {'id': 'C', 'text': parts[3]},
              {'id': 'D', 'text': parts[4]},
            ],
            'correctOptions': [parts[5].toUpperCase()],
            'marks': int.tryParse(parts[6]) ?? 1,
          });
        }
        else if (parts.length >= 2) {
          qData.addAll({
            'type': 'written',
            'stem': parts[0],
            'marks': int.tryParse(parts[1]) ?? 5,
          });
        } else {
          continue; 
        }

        await ref.push().set(qData);
        count++;
      }

      _bulkInputController.clear();
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Imported $count items successfully!');
    } catch (e) {
      _showSnackBar('Error: Check your pipe formatting', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showBulkModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("BULK IMPORT",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
                "MCQ: Question | A | B | C | D | Ans | Marks\nWritten: Question | Marks",
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: _bulkInputController,
              maxLines: 8,
              decoration: _inputDecoration('Paste lines here...'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: brandBlue),
                onPressed: _isSaving ? null : _processBulkQuestions,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("START IMPORT",
                        style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- REORDER LOGIC ---
  Future<void> _updateOrder(List<MapEntry<String, dynamic>> list) async {
    final Map<String, dynamic> updates = {};
    for (int i = 0; i < list.length; i++) {
      updates['exams/${widget.examId}/questions/${list[i].key}/order'] = i;
    }
    await _db.update(updates);
  }

  // --- CLONE & DELETE LOGIC ---
  Future<void> _cloneQuestion(Map<String, dynamic> data) async {
    setState(() => _isSaving = true);
    try {
      final clonedData = Map<String, dynamic>.from(data);
      clonedData['order'] = DateTime.now().millisecondsSinceEpoch;
      await _db
          .child('exams/${widget.examId}/questions')
          .push()
          .set(clonedData);
      _showSnackBar('Cloned successfully!');
    } catch (e) {
      _showSnackBar('Cloning failed', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteQuestion(String qId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Content?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _db.child('exams/${widget.examId}/questions/$qId').remove();
      if (_editingQuestionId == qId) _clearForm();
      _showSnackBar('Deleted successfully');
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
      final marks = _type == 'info_block'
          ? 0
          : (int.tryParse(_marksController.text) ?? 1);
      final qMap = {
        'type': _type,
        'stem': stemText,
        'marks': marks,
        if (_imageUrl != null) 'imageUrl': _imageUrl,
        if (_type.startsWith('mcq'))
          'options': _optionControllers.entries
              .map((e) => {'id': e.key, 'text': e.value.text.trim()})
              .toList(),
        if (_type.startsWith('mcq')) 'correctOptions': _correctOptions.toList(),
        if (_editingQuestionId == null)
          'order': DateTime.now().millisecondsSinceEpoch,
      };

      if (_editingQuestionId != null) {
        await _db
            .child('exams/${widget.examId}/questions/$_editingQuestionId')
            .update(qMap);
      } else {
        await _db.child('exams/${widget.examId}/questions').push().set(qMap);
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
            style: const TextStyle(
                fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.ballot_outlined),
              onPressed: _showBulkModal,
              tooltip: "Bulk Import"),
          if (_editingQuestionId != null)
            IconButton(
                icon: const Icon(Icons.close_rounded), onPressed: _clearForm),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.all(20), child: _buildMainForm())),
          const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text("DRAG HANDLES TO REORDER",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.2)))),
          _buildExistingQuestionsList(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildExistingQuestionsList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _db
          .child('exams/${widget.examId}/questions')
          .orderByChild('order')
          .onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const SliverToBoxAdapter(
              child: Center(child: Text("No content yet")));
        }
        final Map rawData = snapshot.data!.snapshot.value as Map;
        final list = rawData.entries
            .map((e) => MapEntry(e.key.toString(), e.value))
            .toList()
          ..sort((a, b) =>
              (a.value['order'] ?? 0).compareTo(b.value['order'] ?? 0));

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
            return ReorderableDelayedDragStartListener(
              key: ValueKey(e.key),
              index: index,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0))),
                child: ListTile(
                  leading: q['imageUrl'] != null
                      ? const Icon(Icons.image, color: Colors.blue)
                      : const Icon(Icons.help_outline),
                  title: Text(q['stem'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () => _cloneQuestion(q)),
                    IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: brandBlue),
                        onPressed: () => _prepareEdit(e.key, q)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.red),
                        onPressed: () => _deleteQuestion(e.key)),
                    const Icon(Icons.drag_indicator_rounded,
                        color: Color(0xFFCBD5E1)),
                  ]),
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
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('CONTENT TYPE'),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: _inputDecoration('Type'),
            onChanged: (v) => setState(() {
              _type = v!;
              _marksController.text = _type == 'info_block' ? '0' : '1';
            }),
            items: const [
              DropdownMenuItem(
                  value: 'mcq_single', child: Text('MCQ (Single Choice)')),
              DropdownMenuItem(
                  value: 'mcq_multi', child: Text('MCQ (Multiple Choice)')),
              DropdownMenuItem(
                  value: 'written', child: Text('Written Response')),
              DropdownMenuItem(
                  value: 'info_block', child: Text('Info/Stem Block')),
            ],
          ),
          const SizedBox(height: 20),
          _buildImageSection(),
          const SizedBox(height: 20),
          TextField(
              controller: _stemController,
              maxLines: 3,
              decoration: _inputDecoration('Stem Content')),
          const SizedBox(height: 12),
          _buildLivePreview(),
          if (_type != 'info_block') ...[
            const SizedBox(height: 20),
            TextField(
                controller: _marksController,
                decoration: _inputDecoration('Marks'),
                keyboardType: TextInputType.number),
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
        ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(_imageUrl!,
                height: 150, width: double.infinity, fit: BoxFit.cover)),
        Positioned(
            right: 8,
            top: 8,
            child: CircleAvatar(
                backgroundColor: Colors.red,
                child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: () => setState(() => _imageUrl = null)))),
      ]);
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50)),
      onPressed: _isUploading ? null : _pickAndUploadImage,
      icon: _isUploading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.add_a_photo_outlined),
      label: Text(_isUploading ? 'UPLOADING...' : 'ADD IMAGE'),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: brandBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          onPressed: _isSaving ? null : _saveQuestion,
          child: _isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('SAVE CONTENT',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
        ));
  }

  Widget _buildOptionRow(String id) {
    final isSelected = _correctOptions.contains(id);
    return Row(children: [
      Checkbox(
          activeColor: brandBlue,
          value: isSelected,
          onChanged: (v) => setState(() {
                if (v == true && _type == 'mcq_single') _correctOptions.clear();
                v == true
                    ? _correctOptions.add(id)
                    : _correctOptions.remove(id);
              })),
      Expanded(
          child: TextField(
              controller: _optionControllers[id],
              decoration: InputDecoration(
                  hintText: 'Option $id', border: InputBorder.none))),
    ]);
  }

  Widget _buildLivePreview() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: brandBlue.withValues(alpha: 0.1))),
        child: _stemController.text.isEmpty
            ? const Text('Preview...',
                style: TextStyle(color: Colors.grey, fontSize: 12))
            : LatexText(_stemController.text, size: 14),
      );

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF64748B),
          letterSpacing: 1));

  InputDecoration _inputDecoration(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))));

  void _prepareEdit(String qId, Map<String, dynamic> data) {
    setState(() {
      _editingQuestionId = qId;
      _type = data['type'] ?? 'mcq_single';
      _stemController.text = data['stem'] ?? '';
      _marksController.text = (data['marks'] ?? 1).toString();
      _imageUrl = data['imageUrl'];
      _correctOptions.clear();
      if (data['correctOptions'] != null) {
        _correctOptions.addAll(List<String>.from(data['correctOptions']));
      }
      _optionControllers.forEach((k, v) => v.clear());
      if (data['options'] != null) {
        for (final opt in data['options']) {
          if (_optionControllers.containsKey(opt['id'])) {
            _optionControllers[opt['id']]!.text = opt['text'] ?? '';
          }
        }
      }
    });
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  void _clearForm() {
    setState(() {
      _editingQuestionId = null;
      _stemController.clear();
      _marksController.text = '1';
      _imageUrl = null;
      _correctOptions.clear();
      _optionControllers.forEach((k, v) => v.clear());
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600));
  }
}
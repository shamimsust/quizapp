import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../widgets/latex_text.dart';

class BankQuestionEditorScreen extends StatefulWidget {
  final String? questionId; 
  final String parentId;    

  const BankQuestionEditorScreen({
    super.key, 
    this.questionId, 
    required this.parentId
  });

  @override
  State<BankQuestionEditorScreen> createState() => _BankQuestionEditorScreenState();
}

class _BankQuestionEditorScreenState extends State<BankQuestionEditorScreen> {
  final _scrollController = ScrollController();
  final _db = FirebaseDatabase.instance.ref();
  final String _imgBBKey = "bd9c2f7a1ff71a3e72aead970348d485";
  static const Color brandBlue = Color(0xFF2264D7);

  String _type = 'mcq_single';
  final _stemController = TextEditingController();
  final _marksController = TextEditingController(text: '1');
  final _bulkInputController = TextEditingController(); 
  
  String? _editingQuestionId;
  String? _imageUrl;
  bool _isSaving = false;
  bool _isUploading = false;

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
    _editingQuestionId = widget.questionId;
    if (_editingQuestionId != null) {
      _loadExistingData(_editingQuestionId!);
    }
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

  // --- DATABASE OPERATIONS ---
  Future<void> _loadExistingData(String id) async {
    final snapshot = await _db.child('questionBank/$id').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      _prepareEdit(id, data);
    }
  }

  void _prepareEdit(String id, Map<String, dynamic> data) {
    setState(() {
      _editingQuestionId = id;
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
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  Future<void> _saveToBank() async {
    if (_stemController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final qMap = {
        'type': _type,
        'stem': _stemController.text.trim(),
        'marks': _type == 'info_block' ? 0 : (int.tryParse(_marksController.text) ?? 1),
        'parentId': widget.parentId,
        'isFolder': false,
        if (_imageUrl != null) 'imageUrl': _imageUrl,
        if (_type.startsWith('mcq'))
          'options': _optionControllers.entries
              .map((e) => {'id': e.key, 'text': e.value.text.trim()})
              .toList(),
        if (_type.startsWith('mcq')) 'correctOptions': _correctOptions.toList(),
        if (_editingQuestionId == null) 'order': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': ServerValue.timestamp,
      };

      if (_editingQuestionId != null) {
        await _db.child('questionBank/$_editingQuestionId').update(qMap);
      } else {
        await _db.child('questionBank').push().set(qMap);
      }
      
      _clearForm();
      _showSnackBar('Saved to Bank!');
    } catch (e) {
      _showSnackBar('Error saving', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- BULK IMPORT ---
  void _showBulkModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("BULK BANK IMPORT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text("Format: Stem|A|B|C|D|Ans|Marks\nWritten: Quest|Marks\nInfo: No pipes", style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(controller: _bulkInputController, maxLines: 8, decoration: _inputDecoration('Paste lines...')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: brandBlue),
                onPressed: _isSaving ? null : _processBulkQuestions,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("IMPORT TO BANK", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _processBulkQuestions() async {
    final String rawInput = _bulkInputController.text.trim();
    if (rawInput.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      int baseOrder = DateTime.now().millisecondsSinceEpoch;
      final lines = rawInput.split('\n');
      int count = 0;

      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final parts = trimmed.split('|').map((e) => e.trim()).toList();
        final Map<String, dynamic> qData = {
          'parentId': widget.parentId,
          'isFolder': false,
          'order': baseOrder++,
          'createdAt': ServerValue.timestamp,
        };

        if (parts.length >= 7) {
          qData.addAll({
            'type': 'mcq_single', 'stem': parts[0],
            'options': [{'id': 'A', 'text': parts[1]}, {'id': 'B', 'text': parts[2]}, {'id': 'C', 'text': parts[3]}, {'id': 'D', 'text': parts[4]}],
            'correctOptions': [parts[5].toUpperCase()], 'marks': int.tryParse(parts[6]) ?? 1,
          });
        } else if (parts.length >= 2) {
          qData.addAll({'type': 'written', 'stem': parts[0], 'marks': int.tryParse(parts[1]) ?? 5});
        } else {
          qData.addAll({'type': 'info_block', 'stem': parts[0], 'marks': 0});
        }
        await _db.child('questionBank').push().set(qData);
        count++;
      }
      _bulkInputController.clear();
      Navigator.pop(context);
      _showSnackBar('Imported $count items successfully!');
    } catch (e) {
      _showSnackBar('Check your pipe formatting', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- IMGBB UPLOAD ---
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final Uint8List bytes = await image.readAsBytes(); 
      final String base64Image = base64Encode(bytes);
      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {'key': _imgBBKey, 'image': base64Image},
      );
      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() => _imageUrl = jsonResponse['data']['url']);
        _showSnackBar('Image uploaded!');
      }
    } catch (e) {
      _showSnackBar('Upload failed', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- UI COMPONENTS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_editingQuestionId == null ? 'NEW BANK ITEM' : 'EDIT BANK ITEM',
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.ballot_outlined), onPressed: _showBulkModal, tooltip: "Bulk Import"),
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
          const SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text("EXISTING IN THIS FOLDER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.2)),
          )),
          _buildExistingQuestionsList(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildMainForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<String>(
          value: _type,
          decoration: _inputDecoration('Type'),
          onChanged: (v) => setState(() {
            _type = v!;
            _marksController.text = _type == 'info_block' ? '0' : '1';
          }),
          items: const [
            DropdownMenuItem(value: 'mcq_single', child: Text('MCQ (Single)')),
            DropdownMenuItem(value: 'mcq_multi', child: Text('MCQ (Multiple)')),
            DropdownMenuItem(value: 'written', child: Text('Written')),
            DropdownMenuItem(value: 'info_block', child: Text('Info Block')),
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
      ]),
    );
  }

  Widget _buildExistingQuestionsList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _db.child('questionBank').orderByChild('parentId').equalTo(widget.parentId).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Folder is empty"))));
        }
        final Map rawData = snapshot.data!.snapshot.value as Map;
        final list = rawData.entries.where((e) => e.value['isFolder'] != true)
            .map((e) => MapEntry(e.key.toString(), e.value))
            .toList()
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
            return ReorderableDelayedDragStartListener(
              key: ValueKey(e.key),
              index: index,
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: ListTile(
                  leading: Text("${index + 1}.", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  title: Text(q['stem'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: brandBlue), onPressed: () => _prepareEdit(e.key, q)),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), 
                      onPressed: () => _db.child('questionBank/${e.key}').remove()),
                    const Icon(Icons.drag_indicator_rounded, color: Color(0xFFCBD5E1)),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- HELPER UI ---
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
      label: Text(_isUploading ? 'UPLOADING...' : 'ADD IMAGE'),
    );
  }

  Widget _buildOptionRow(String id) {
    return Row(children: [
      Checkbox(
        activeColor: brandBlue,
        value: _correctOptions.contains(id),
        onChanged: (v) => setState(() {
          if (v == true && _type == 'mcq_single') _correctOptions.clear();
          v == true ? _correctOptions.add(id) : _correctOptions.remove(id);
        })),
      Expanded(child: TextField(controller: _optionControllers[id], decoration: InputDecoration(hintText: 'Option $id', border: InputBorder.none))),
    ]);
  }

  Widget _buildLivePreview() => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: brandBlue.withAlpha(25))),
    child: _stemController.text.isEmpty ? const Text('Preview...', style: TextStyle(color: Colors.grey, fontSize: 12)) : LatexText(_stemController.text, size: 14),
  );

  Widget _buildSaveButton() => SizedBox(
    width: double.infinity, height: 56,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: brandBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      onPressed: _isSaving ? null : _saveToBank,
      child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE TO BANK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
  );

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
  );

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green.shade600));
  }

  Future<void> _updateOrder(List<MapEntry<String, dynamic>> list) async {
    final Map<String, dynamic> updates = {};
    for (int i = 0; i < list.length; i++) {
      updates['questionBank/${list[i].key}/order'] = i;
    }
    await _db.update(updates);
  }
}
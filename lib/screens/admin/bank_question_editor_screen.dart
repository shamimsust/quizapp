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
  final _db = FirebaseDatabase.instance.ref();
  final String _imgBBKey = "bd9c2f7a1ff71a3e72aead970348d485";
  static const Color brandBlue = Color(0xFF2264D7);

  String _type = 'mcq_single';
  final _stemController = TextEditingController();
  final _marksController = TextEditingController(text: '1');
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
    if (widget.questionId != null) {
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    final snapshot = await _db.child('questionBank/${widget.questionId}').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        _type = data['type'] ?? 'mcq_single';
        _stemController.text = data['stem'] ?? '';
        _marksController.text = (data['marks'] ?? 1).toString();
        _imageUrl = data['imageUrl'];
        if (data['correctOptions'] != null) {
          _correctOptions.addAll(List<String>.from(data['correctOptions']));
        }
        if (data['options'] != null) {
          for (var opt in data['options']) {
            _optionControllers[opt['id']]?.text = opt['text'] ?? '';
          }
        }
      });
    }
  }

  Future<void> _saveToBank() async {
    if (_stemController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final qMap = {
        'type': _type,
        'stem': _stemController.text.trim(),
        'marks': int.tryParse(_marksController.text) ?? 1,
        'parentId': widget.parentId,
        'isFolder': false,
        if (_imageUrl != null) 'imageUrl': _imageUrl,
        if (_type.startsWith('mcq'))
          'options': _optionControllers.entries
              .map((e) => {'id': e.key, 'text': e.value.text.trim()})
              .toList(),
        if (_type.startsWith('mcq')) 'correctOptions': _correctOptions.toList(),
      };

      if (widget.questionId != null) {
        await _db.child('questionBank/${widget.questionId}').update(qMap);
      } else {
        await _db.child('questionBank').push().set(qMap);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Save error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final Uint8List bytes = await image.readAsBytes(); 
      final String base64Image = base64Encode(bytes);
      final response = await http.post(
        Uri.parse('https://api.api.imgbb.com/1/upload'),
        body: {'key': _imgBBKey, 'image': base64Image},
      );
      final jsonResponse = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() => _imageUrl = jsonResponse['data']['url']);
      }
    } catch (e) {
      debugPrint("Upload failed: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.questionId == null ? 'NEW BANK QUESTION' : 'EDIT BANK QUESTION',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1)),
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0))
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDropdown(),
              const SizedBox(height: 20),
              _buildImageSection(),
              const SizedBox(height: 20),
              TextField(
                controller: _stemController,
                maxLines: 4,
                decoration: _inputDecoration('Question Content (LaTeX)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _buildPreview(),
              if (_type != 'info_block') ...[
                const SizedBox(height: 20),
                TextField(controller: _marksController, decoration: _inputDecoration('Marks'), keyboardType: TextInputType.number),
              ],
              if (_type.startsWith('mcq')) ...[
                const SizedBox(height: 30),
                ...['A', 'B', 'C', 'D'].map((id) => _buildOptionRow(id)),
              ],
              const SizedBox(height: 40),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _type,
      decoration: _inputDecoration('Type'),
      items: const [
        DropdownMenuItem(value: 'mcq_single', child: Text('MCQ (Single)')),
        DropdownMenuItem(value: 'mcq_multi', child: Text('MCQ (Multiple)')),
        DropdownMenuItem(value: 'written', child: Text('Written')),
        DropdownMenuItem(value: 'info_block', child: Text('Info Block')),
      ],
      onChanged: (v) => setState(() => _type = v!),
    );
  }

  Widget _buildOptionRow(String id) {
    return Row(
      children: [
        Checkbox(
          activeColor: brandBlue,
          value: _correctOptions.contains(id),
          onChanged: (v) {
            setState(() {
              if (v == true && _type == 'mcq_single') _correctOptions.clear();
              v == true ? _correctOptions.add(id) : _correctOptions.remove(id);
            });
          }
        ),
        Expanded(child: TextField(controller: _optionControllers[id], decoration: InputDecoration(hintText: 'Option $id', border: InputBorder.none))),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: _stemController.text.isEmpty 
        ? const Text("Live LaTeX Preview...", style: TextStyle(color: Colors.grey, fontSize: 12))
        : LatexText(_stemController.text, size: 14),
    );
  }

  Widget _buildImageSection() {
    if (_imageUrl != null) {
      return Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_imageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover)),
          Positioned(right: 5, top: 5, child: CircleAvatar(backgroundColor: Colors.red, child: IconButton(icon: const Icon(Icons.delete, color: Colors.white), onPressed: () => setState(() => _imageUrl = null)))),
        ],
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
      onPressed: _isUploading ? null : _pickAndUploadImage,
      icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image_outlined),
      label: Text(_isUploading ? "UPLOADING..." : "ADD IMAGE"),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: brandBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _isSaving ? null : _saveToBank,
        child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE TO BANK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
  );
}
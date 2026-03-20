import 'package:flutter/material.dart';
import 'package:math_keyboard/math_keyboard.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class MathAnswerField extends StatefulWidget {
  final void Function(String latex) onChanged;
  const MathAnswerField({super.key, required this.onChanged});

  @override
  State<MathAnswerField> createState() => _MathAnswerFieldState();
}

class _MathAnswerFieldState extends State<MathAnswerField> {
  late MathFieldEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = MathFieldEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MathField(
          controller: controller,
          variables: const ['x','y','z'],
          onChanged: (value) => widget.onChanged(value),
        ),
        const SizedBox(height: 8),
        const Text('Preview:'),
        Math.tex(controller.currentEditingValue(), textStyle: const TextStyle(fontSize: 16)),
      ],
    );
  }
}

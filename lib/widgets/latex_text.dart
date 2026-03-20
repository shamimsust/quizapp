import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class LatexText extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;

  const LatexText(this.text, {super.key, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) {
    // This Regex finds content between $ symbols
    final regex = RegExp(r'(\$.*?\$)', dotAll: true);
    final parts = text.split(regex);
    final matches = regex.allMatches(text).map((m) => m.group(0)).toList();

    final List<Widget> spans = [];

    for (var i = 0; i < parts.length; i++) {
      // 1. Add the plain text part (Bangla/English)
      if (parts[i].isNotEmpty) {
        spans.add(Text(
          parts[i],
          style: TextStyle(
            fontSize: size,
            color: color ?? Colors.black87,
            fontFamily: 'Inter', // Ensuring your brand font is used
          ),
        ));
      }

      // 2. Add the Math part (LaTeX)
      if (i < matches.length) {
        final mathContent = matches[i]!.replaceAll('\$', ''); // Remove the $ signs
        spans.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Math.tex(
            mathContent,
            mathStyle: MathStyle.text,
            textStyle: TextStyle(fontSize: size + 2, color: color),
            onErrorFallback: (err) => Text(
              matches[i]!, 
              style: const TextStyle(color: Colors.red)
            ),
          ),
        ));
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: spans,
    );
  }
}
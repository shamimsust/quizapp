import 'package:flutter/material.dart';

class McqOptionTile extends StatelessWidget {
  final String id;
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const McqOptionTile({super.key, required this.id, required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(id)),
      title: Text(text),
      trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.circle_outlined),
      onTap: onTap,
    );
  }
}

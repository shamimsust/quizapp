import 'dart:async';
import 'package:flutter/material.dart';

class ExamTimer extends StatefulWidget {
  final int endTimeMs;
  final VoidCallback onTimeUp;
  const ExamTimer({super.key, required this.endTimeMs, required this.onTimeUp});

  @override
  State<ExamTimer> createState() => _ExamTimerState();
}

class _ExamTimerState extends State<ExamTimer> {
  late Timer _timer;
  int remaining = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() => remaining = (widget.endTimeMs - now).clamp(0, 1 << 30));
    if (remaining <= 0) {
      _timer.cancel();
      widget.onTimeUp();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = Duration(milliseconds: remaining);
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Chip(label: Text('$mm:$ss'));
  }
}

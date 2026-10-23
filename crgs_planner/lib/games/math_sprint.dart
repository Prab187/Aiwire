import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../store.dart';
import '../widgets.dart';
import 'age_groups.dart';

class MathSprint extends StatefulWidget {
  const MathSprint({super.key, required this.store, required this.group});
  final AppStore store;
  final AgeGroup group;

  @override
  State<MathSprint> createState() => _MathSprintState();
}

class _MathSprintState extends State<MathSprint> {
  final _rnd = Random();
  final _answer = TextEditingController();
  Timer? _timer;
  MathQuestion? _q;
  String _display = 'Ready?';
  String? _wrongHint;
  int _score = 0;
  int _left = 60;
  bool get _running => _timer != null;

  @override
  void dispose() {
    _timer?.cancel();
    _answer.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _score = 0;
      _left = 60;
      _wrongHint = null;
      _next();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left--);
      if (_left <= 0) _finish();
    });
  }

  void _next() {
    _q = widget.group.question(_rnd);
    _display = _q!.text;
    _answer.clear();
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    final key = widget.group.key;
    final best = widget.store.data.games.best[key] ?? 0;
    final isBest = _score > best;
    if (isBest) widget.store.update((d) => d.games.best[key] = _score, clearsExample: false);
    setState(() => _display = isBest ? 'New best: $_score!' : 'You got $_score');
  }

  void _submit() {
    if (!_running || _q == null) return;
    final v = int.tryParse(_answer.text.trim().replaceAll('−', '-'));
    if (v == null) return;
    setState(() {
      if (v == _q!.answer) {
        _score++;
        _wrongHint = null;
      } else {
        _wrongHint = "Not quite, it's ${_q!.answer}";
      }
      _next();
    });
  }

  @override
  Widget build(BuildContext context) {
    final best = widget.store.data.games.best[widget.group.key] ?? 0;
    return Panel(
      title: 'Maths sprint',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Note('${widget.group.mathRule} Beat the clock: 60 seconds.'),
          const SizedBox(height: 16),
          Text(_display, textAlign: TextAlign.center, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800)),
          SizedBox(height: 22, child: Center(child: Text(_wrongHint ?? '', style: TextStyle(color: Theme.of(context).colorScheme.error)))),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _answer,
                  enabled: _running,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22),
                  keyboardType: TextInputType.numberWithOptions(signed: widget.group.negativeAnswers),
                  decoration: const InputDecoration(hintText: 'Your answer', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _running ? _submit : _start,
                style: FilledButton.styleFrom(minimumSize: const Size(96, 56)),
                child: Text(_running ? 'Answer' : (_left == 60 && _score == 0 && _display == 'Ready?' ? 'Start' : 'Play again')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 16,
            runSpacing: 4,
            children: [_stat(context, 'Score', '$_score'), _stat(context, 'Time', '$_left'), _stat(context, 'Best', '$best')],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      );
}

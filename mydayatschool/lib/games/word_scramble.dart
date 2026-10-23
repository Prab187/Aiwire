import 'dart:math';

import 'package:flutter/material.dart';

import '../store.dart';
import '../subjects.dart' as subj;
import '../widgets.dart';
import 'age_groups.dart';

class WordScramble extends StatefulWidget {
  const WordScramble({super.key, required this.store, required this.group});
  final AppStore store;
  final AgeGroup group;

  @override
  State<WordScramble> createState() => _WordScrambleState();
}

class _WordScrambleState extends State<WordScramble> {
  final _rnd = Random();
  final _answer = TextEditingController();
  late String _subject;
  late String _word;
  late String _scrambled;
  String? _message;

  @override
  void initState() {
    super.initState();
    _nextWord();
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _nextWord() {
    final (s, w) = widget.group.words[_rnd.nextInt(widget.group.words.length)];
    var sc = w;
    while (sc == w) {
      sc = (w.split('')..shuffle(_rnd)).join();
    }
    _subject = s;
    _word = w;
    _scrambled = sc.toUpperCase();
    _answer.clear();
  }

  void _check() {
    final g = widget.store.data.games;
    if (_answer.text.trim().toLowerCase() == _word) {
      widget.store.update((d) {
        d.games.wordStreak++;
        if (d.games.wordStreak > d.games.wordBest) d.games.wordBest = d.games.wordStreak;
      }, clearsExample: false);
      setState(() {
        _message = 'Correct!';
        _nextWord();
      });
    } else {
      if (g.wordStreak != 0) widget.store.update((d) => d.games.wordStreak = 0, clearsExample: false);
      setState(() => _message = 'Try again');
    }
  }

  void _skip() {
    widget.store.update((d) => d.games.wordStreak = 0, clearsExample: false);
    setState(() {
      _message = 'It was ${_word.toUpperCase()}';
      _nextWord();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.store.data.games;
    return Panel(
      title: 'Word scramble',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Note('Unscramble the word. The subject is your clue.'),
          const SizedBox(height: 14),
          Center(child: subj.SubjectChip(_subject)),
          const SizedBox(height: 10),
          Text(_scrambled, textAlign: TextAlign.center, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: 3)),
          SizedBox(height: 24, child: Center(child: Text(_message ?? '', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)))),
          TextField(
            controller: _answer,
            textAlign: TextAlign.center,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            style: const TextStyle(fontSize: 22),
            decoration: const InputDecoration(hintText: 'Your answer', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
            onSubmitted: (_) => _check(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: FilledButton(onPressed: _check, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), child: const Text('Check'))),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _skip, style: OutlinedButton.styleFrom(minimumSize: const Size(80, 50)), child: const Text('Skip')),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 16,
            runSpacing: 4,
            children: [
              Text.rich(TextSpan(children: [const TextSpan(text: 'Streak '), TextSpan(text: '${g.wordStreak}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))])),
              Text.rich(TextSpan(children: [const TextSpan(text: 'Best '), TextSpan(text: '${g.wordBest}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))])),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../data.dart';
import '../widgets.dart';

/// Anlama soruları: seçenekleri karıştırır, her soruda geri bildirim verir, sonunda yüzde döndürür.
class QuizPage extends StatefulWidget {
  final String title;
  final List<Quiz> questions;
  final Future<void> Function(int percent) onDone;
  final Widget? footer; // sonuçta gösterilecek ek içerik
  const QuizPage({
    super.key,
    required this.title,
    required this.questions,
    required this.onDone,
    this.footer,
  });
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _r = Random();
  late final List<_Q> _q;
  int _i = 0, _dogru = 0;
  int? _secim;
  bool _bitti = false;

  @override
  void initState() {
    super.initState();
    _q = widget.questions.map((x) {
      final dogru = x.options[x.answer];
      final o = List<String>.of(x.options)..shuffle(_r);
      return _Q(x.q, o, o.indexOf(dogru), x.why);
    }).toList();
  }

  Future<void> _ilerle() async {
    if (_i + 1 >= _q.length) {
      final yuzde = (_dogru * 100 / _q.length).round();
      await widget.onDone(yuzde);
      if (mounted) setState(() => _bitti = true);
      return;
    }
    setState(() {
      _i++;
      _secim = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (_bitti) {
      final yuzde = (_dogru * 100 / _q.length).round();
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Ring(
                value: yuzde / 100,
                label: '$_dogru/${_q.length}',
                sub: 'doğru',
                size: 140,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                yuzde == 100
                    ? 'Mükemmel!'
                    : yuzde >= 60
                    ? 'İyi iş!'
                    : 'Bir daha dinle/oku ve tekrar dene.',
                style: t.textTheme.titleLarge,
              ),
            ),
            if (widget.footer != null) ...[
              const SizedBox(height: 20),
              widget.footer!,
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bitir'),
            ),
          ],
        ),
      );
    }
    final q = _q[_i];
    final cevaplandi = _secim != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} · ${_i + 1}/${_q.length}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: _i / _q.length),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  q.text,
                  style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                ChoiceList(
                  options: q.options,
                  selected: _secim,
                  correct: cevaplandi ? q.answer : null,
                  onSelect: (i) {
                    setState(() {
                      _secim = i;
                      if (i == q.answer) _dogru++;
                    });
                  },
                ),
              ],
            ),
          ),
          if (cevaplandi)
            FeedbackBar(
              correct: _secim == q.answer,
              title: _secim == q.answer ? 'Doğru!' : 'Yanlış',
              detail: q.why.isEmpty ? null : q.why,
              nextLabel: _i + 1 >= _q.length ? 'Sonucu gör' : 'Devam',
              onNext: _ilerle,
            ),
        ],
      ),
    );
  }
}

class _Q {
  final String text, why;
  final List<String> options;
  final int answer;
  _Q(this.text, this.options, this.answer, this.why);
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../data.dart';
import '../speech.dart';
import '../store.dart';
import '../text_utils.dart';
import '../widgets.dart';
import 'quiz.dart';

class ListeningPage extends StatelessWidget {
  const ListeningPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Content.i;
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Dinleme')),
      body: ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              color: t.colorScheme.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DictationPage()),
              ),
              child: Row(
                children: [
                  Icon(Icons.hearing, color: t.colorScheme.onPrimary, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dikte',
                          style: t.textTheme.titleMedium?.copyWith(
                            color: t.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Cümleyi dinle, duyduğunu yaz',
                          style: t.textTheme.bodySmall?.copyWith(
                            color: t.colorScheme.onPrimary.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: t.colorScheme.onPrimary),
                ],
              ),
            ),
            const SectionTitle('Diyaloglar'),
            for (final d in c.dialogues)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DialoguePage(d: d)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.title, style: t.textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                LevelChip(d.level),
                                const SizedBox(width: 8),
                                Text(
                                  '~${d.minutes} dk · ${d.questions.length} soru',
                                  style: t.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (Store.i.best['dlg:${d.id}'] != null)
                        Chip(
                          avatar: const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.green,
                          ),
                          label: Text('%${Store.i.best['dlg:${d.id}']}'),
                        )
                      else
                        const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diyalog oynatıcı
// ---------------------------------------------------------------------------

class DialoguePage extends StatefulWidget {
  final Dialogue d;
  const DialoguePage({super.key, required this.d});
  @override
  State<DialoguePage> createState() => _DialoguePageState();
}

class _DialoguePageState extends State<DialoguePage> {
  int _aktif = -1;
  bool _caliyor = false;
  bool _yavas = false;
  bool _metin = false;
  bool _dinlendi = false;
  int _oturum = 0;

  @override
  void dispose() {
    _oturum++;
    Tts.i.stop();
    super.dispose();
  }

  Future<void> _oynat({int baslangic = 0, bool tek = false}) async {
    final benim = ++_oturum;
    await Tts.i.stop();
    setState(() => _caliyor = true);
    final satirlar = widget.d.lines;
    for (var i = baslangic; i < satirlar.length; i++) {
      if (!mounted || benim != _oturum) return;
      setState(() => _aktif = i);
      await Tts.i.speak(
        satirlar[i].text,
        konusmaci: satirlar[i].speaker,
        yavas: _yavas,
      );
      if (!mounted || benim != _oturum) return;
      if (tek) break;
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (!mounted || benim != _oturum) return;
    setState(() {
      _caliyor = false;
      _aktif = -1;
      if (!tek) _dinlendi = true;
    });
  }

  Future<void> _durdur() async {
    _oturum++;
    await Tts.i.stop();
    if (mounted) {
      setState(() {
        _caliyor = false;
        _aktif = -1;
      });
    }
  }

  void _sorulara() {
    _durdur();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPage(
          title: widget.d.title,
          questions: widget.d.questions,
          onDone: (yuzde) async {
            await Store.i.saveBest('dlg:${widget.d.id}', yuzde);
            await Store.i.markListening();
            await Store.i.addXp(10 + yuzde ~/ 10);
          },
          footer: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Konuşmanın özeti',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(widget.d.about),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final d = widget.d;
    return Scaffold(
      appBar: AppBar(title: Text(d.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    LevelChip(d.level),
                    const SizedBox(width: 8),
                    Text(
                      '${d.lines.length} cümle',
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filled(
                            iconSize: 40,
                            onPressed: _caliyor ? _durdur : () => _oynat(),
                            icon: Icon(
                              _caliyor
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Normal')),
                          ButtonSegment(value: true, label: Text('Yavaş')),
                        ],
                        selected: {_yavas},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) =>
                            setState(() => _yavas = s.first),
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Metni göster'),
                        subtitle: const Text(
                          'Önce metne bakmadan dinlemeyi dene',
                        ),
                        value: _metin,
                        onChanged: (v) => setState(() => _metin = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_metin)
                  for (var i = 0; i < d.lines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        color: i == _aktif
                            ? t.colorScheme.primaryContainer
                            : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        onTap: () => _oynat(baslangic: i, tek: true),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!d.singleSpeaker)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: d.lines[i].speaker == 0
                                      ? t.colorScheme.primary
                                      : t.colorScheme.tertiary,
                                  child: Text(
                                    d.lines[i].speaker == 0 ? 'A' : 'B',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                d.lines[i].text,
                                style: t.textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                else
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _caliyor
                          ? 'Dinliyorsun… ${_aktif + 1}/${d.lines.length}'
                          : 'Oynat düğmesine bas. Gerekirse tekrar dinle, sonra soruları çöz.',
                      textAlign: TextAlign.center,
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sorulara,
                  icon: const Icon(Icons.quiz_outlined),
                  label: Text(
                    _dinlendi ? 'Soruları çöz' : 'Soruları çöz (önce dinle)',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dikte
// ---------------------------------------------------------------------------

class DictationPage extends StatefulWidget {
  const DictationPage({super.key});
  @override
  State<DictationPage> createState() => _DictationPageState();
}

class _DictationPageState extends State<DictationPage> {
  final _r = Random();
  final _yazi = TextEditingController();
  String? _seviye; // null: hepsi
  List<Sentence>? _liste;
  int _i = 0;
  WordAlignment? _sonuc;
  final List<int> _puanlar = [];
  bool _cevirGoster = false;

  @override
  void dispose() {
    _yazi.dispose();
    Tts.i.stop();
    super.dispose();
  }

  void _basla(String? seviye) {
    final tum = Content.i.sentences
        .where((s) => seviye == null || s.level == seviye)
        .toList();
    setState(() {
      _seviye = seviye;
      _liste = pick(tum, min(8, tum.length), _r);
      _i = 0;
      _sonuc = null;
      _puanlar.clear();
    });
    _oku();
  }

  void _oku({bool? yavas}) => Tts.i.speak(_liste![_i].text, yavas: yavas);

  void _kontrol() {
    final s = _liste![_i];
    final a = align(s.text, _yazi.text);
    setState(() {
      _sonuc = a;
      _puanlar.add(a.percent);
    });
  }

  Future<void> _sonraki() async {
    if (_i + 1 >= _liste!.length) {
      final ort = (_puanlar.fold(0, (a, b) => a + b) / _puanlar.length).round();
      await Store.i.markListening();
      await Store.i.addXp(10 + ort ~/ 5);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dikte bitti'),
          content: Text('Ortalama doğruluk: %$ort'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() {
      _i++;
      _sonuc = null;
      _cevirGoster = false;
      _yazi.clear();
    });
    _oku();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (_liste == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dikte')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Her turda 8 cümle dinler ve duyduğunu yazarsın. Cümle başına istediğin kadar tekrar dinleyebilirsin.',
              style: t.textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Text('Seviye seç', style: t.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final v in const [
              ['A2', 'Kolay (A2)'],
              ['B1', 'Orta (B1)'],
              ['B2', 'Zor (B2)'],
              [null, 'Karışık'],
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => _basla(v[0]),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(v[1]!, style: t.textTheme.titleMedium),
                      ),
                      const Icon(Icons.play_arrow_rounded),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    final s = _liste![_i];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dikte ${_i + 1}/${_liste!.length}${_seviye == null ? '' : ' · $_seviye'}',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: _i / _liste!.length),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      iconSize: 36,
                      onPressed: () => _oku(yavas: false),
                      icon: const Icon(Icons.volume_up_rounded),
                    ),
                    const SizedBox(width: 14),
                    IconButton.filledTonal(
                      iconSize: 36,
                      onPressed: () => _oku(yavas: true),
                      icon: const Icon(Icons.slow_motion_video),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('Normal · Yavaş', style: t.textTheme.labelSmall),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _yazi,
                  enabled: _sonuc == null,
                  minLines: 2,
                  maxLines: 4,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Duyduğun cümleyi yaz',
                  ),
                ),
                const SizedBox(height: 12),
                if (_sonuc == null)
                  FilledButton(
                    onPressed: _kontrol,
                    child: const Text('Kontrol et'),
                  )
                else ...[
                  Text(
                    '%${_sonuc!.percent} doğru',
                    style: t.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  WordChips(words: _sonuc!.targetWords, hit: _sonuc!.hit),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.text, style: t.textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        if (_cevirGoster)
                          Text(
                            s.tr,
                            style: t.textTheme.bodyMedium?.copyWith(
                              color: t.colorScheme.primary,
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () =>
                                setState(() => _cevirGoster = true),
                            child: const Text('Türkçesini göster'),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_sonuc != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _sonraki,
                    child: Text(
                      _i + 1 >= _liste!.length ? 'Bitir' : 'Sonraki cümle',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

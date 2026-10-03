import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../speech.dart';
import '../store.dart';
import '../widgets.dart';
import 'quiz.dart';

class ReadingPage extends StatelessWidget {
  const ReadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Okuma'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Makaleler'),
              Tab(text: 'Bağlantılar'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ArticleList(), _LinkList()]),
      ),
    );
  }
}

class _ArticleList extends StatelessWidget {
  const _ArticleList();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Uygulamanın içinde, internetsiz de okuyabileceğin kısa makaleler. Bilinmeyen sözcüklere dokun, Türkçesini gör.',
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          for (final a in Content.i.articles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ArticlePage(a: a)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title, style: t.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            a.summary,
                            style: t.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              LevelChip(a.level),
                              const SizedBox(width: 8),
                              Text(
                                '${a.minutes} dk okuma',
                                style: t.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (Store.i.readArticles.contains(a.id))
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check_circle, color: Colors.green),
                      )
                    else
                      const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinkList extends StatelessWidget {
  const _LinkList();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Kendi alanında İngilizce okumak için güvenilir siteler. Düzenli oku: günde 1 makale bile çok fark yaratır.',
          style: t.textTheme.bodyMedium?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        for (final l in Content.i.links)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () async {
                final ok = await launchUrl(
                  Uri.parse(l.url),
                  mode: LaunchMode.externalApplication,
                );
                if (!ok && context.mounted) {
                  snack(context, 'Bağlantı açılamadı: ${l.url}');
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                l.title,
                                style: t.textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l.level,
                              style: t.textTheme.labelSmall?.copyWith(
                                color: t.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(l.note, style: t.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 20),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Paragrafı [sozluk] anahtarlarına göre parçalara böler. Eşleşen parçalar dokunulabilir olur.
List<({String text, String? key})> parcala(
  String metin,
  Iterable<String> anahtarlar,
) {
  final k = anahtarlar.toList()..sort((a, b) => b.length.compareTo(a.length));
  if (k.isEmpty) return [(text: metin, key: null)];
  final re = RegExp(
    '(?<![A-Za-z])(${k.map(RegExp.escape).join('|')})(?![A-Za-z])',
    caseSensitive: false,
  );
  final sonuc = <({String text, String? key})>[];
  var son = 0;
  for (final m in re.allMatches(metin)) {
    if (m.start > son) {
      sonuc.add((text: metin.substring(son, m.start), key: null));
    }
    sonuc.add((text: m.group(0)!, key: m.group(0)!.toLowerCase()));
    son = m.end;
  }
  if (son < metin.length) sonuc.add((text: metin.substring(son), key: null));
  return sonuc;
}

class ArticlePage extends StatefulWidget {
  final Article a;
  const ArticlePage({super.key, required this.a});
  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  double _boyut = 18;
  bool _ozet = false;
  int _okunan = -1;
  bool _caliyor = false;
  int _oturum = 0;
  late final Map<String, String> _sozluk; // küçük harfli anahtar -> Türkçe

  @override
  void initState() {
    super.initState();
    final c = Content.i;
    _sozluk = {
      for (final e in widget.a.glossary.entries) e.key.toLowerCase(): e.value,
    };
    // Yeterince özgün (uzun ya da çok sözcüklü) kelime listesi terimleri de dokunulabilir olsun
    final govde = widget.a.paragraphs.join(' ').toLowerCase();
    for (final w in c.words) {
      final k = w.term.toLowerCase();
      if ((k.length >= 7 || k.contains(' ')) &&
          govde.contains(k) &&
          !_sozluk.containsKey(k)) {
        _sozluk[k] = w.tr;
      }
    }
  }

  @override
  void dispose() {
    _oturum++;
    Tts.i.stop();
    super.dispose();
  }

  Future<void> _dinle() async {
    final benim = ++_oturum;
    await Tts.i.stop();
    setState(() => _caliyor = true);
    for (var i = 0; i < widget.a.paragraphs.length; i++) {
      if (!mounted || benim != _oturum) return;
      setState(() => _okunan = i);
      await Tts.i.speak(widget.a.paragraphs[i]);
    }
    if (mounted && benim == _oturum) {
      setState(() {
        _caliyor = false;
        _okunan = -1;
      });
    }
  }

  Future<void> _durdur() async {
    _oturum++;
    await Tts.i.stop();
    if (mounted) {
      setState(() {
        _caliyor = false;
        _okunan = -1;
      });
    }
  }

  void _kelime(String anahtar) {
    final t = Theme.of(context);
    final tr = _sozluk[anahtar] ?? '';
    final kelime = Content.i.byTerm[anahtar];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      anahtar,
                      style: t.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SpeakButton(anahtar, tonal: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr,
                style: t.textTheme.titleLarge?.copyWith(
                  color: t.colorScheme.primary,
                ),
              ),
              if (kelime != null) ...[
                const SizedBox(height: 10),
                Text(kelime.def),
                const SizedBox(height: 8),
                Text(
                  '“${kelime.ex}”',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _sorular() {
    _durdur();
    final a = widget.a;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPage(
          title: 'Anlama soruları',
          questions: a.questions,
          onDone: (yuzde) async {
            await Store.i.saveBest('art:${a.id}', yuzde);
            await Store.i.markReading(a.id);
            await Store.i.addXp(15 + yuzde ~/ 10);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = widget.a;
    return Scaffold(
      appBar: AppBar(
        title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Yazıyı küçült',
            onPressed: () =>
                setState(() => _boyut = (_boyut - 1).clamp(14, 28)),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: 'Yazıyı büyüt',
            onPressed: () =>
                setState(() => _boyut = (_boyut + 1).clamp(14, 28)),
            icon: const Icon(Icons.text_increase),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Row(
                  children: [
                    LevelChip(a.level),
                    const SizedBox(width: 8),
                    Text(
                      '${a.minutes} dk · ${a.words} sözcük',
                      style: t.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: _caliyor ? _durdur : _dinle,
                      icon: Icon(_caliyor ? Icons.stop : Icons.headphones),
                      label: Text(_caliyor ? 'Durdur' : 'Dinle'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  a.title,
                  style: t.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => _ozet = !_ozet),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          _ozet ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text('Türkçe özet', style: t.textTheme.labelLarge),
                      ],
                    ),
                  ),
                ),
                if (_ozet)
                  AppCard(
                    color: t.colorScheme.secondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    child: Text(a.summary),
                  ),
                const SizedBox(height: 10),
                for (var i = 0; i < a.paragraphs.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: i == _okunan
                          ? t.colorScheme.primaryContainer.withValues(
                              alpha: 0.6,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          for (final p in parcala(
                            a.paragraphs[i],
                            _sozluk.keys,
                          ))
                            p.key == null
                                ? TextSpan(text: p.text)
                                : TextSpan(
                                    text: p.text,
                                    style: TextStyle(
                                      color: t.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationStyle:
                                          TextDecorationStyle.dotted,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _kelime(p.key!),
                                  ),
                        ],
                      ),
                      style: t.textTheme.bodyLarge?.copyWith(
                        fontSize: _boyut,
                        height: 1.55,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Altı çizili sözcüklere dokun: Türkçe karşılığı açılır.',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
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
                  onPressed: _sorular,
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Anlama sorularını çöz'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

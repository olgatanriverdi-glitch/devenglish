import 'dart:math';

import 'package:flutter/material.dart';

import '../data.dart';
import '../speech.dart';
import '../store.dart';
import '../text_utils.dart';
import '../widgets.dart';

/// Kelime sekmesi: durum özeti + çalışma başlatma + kelime listesi.
class WordsPage extends StatelessWidget {
  const WordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Content.i;
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        final due = s.dueWords(c).length;
        final yeni = s.newRemaining(c);
        final t = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Kelimeler')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c.words.length} kelimelik yazılım sözlüğü',
                      style: t.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    _Cubuk(
                      yeni: yeni,
                      ogreniliyor: s.learningCount,
                      ustalasan: s.masteredCount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _BaslatKarti(
                ikon: Icons.auto_awesome,
                baslik: 'Günlük çalışma',
                alt: due + min(5, yeni) == 0
                    ? 'Bugünlük bitti, harika!'
                    : '$due tekrar + ${min(5, yeni)} yeni kelime',
                vurgulu: true,
                onTap: due + min(5, yeni) == 0
                    ? null
                    : () => _ac(context, due: true, yeniSayi: 5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _BaslatKarti(
                      ikon: Icons.add_circle_outline,
                      baslik: 'Yeni öğren',
                      alt: yeni == 0 ? 'Hepsi görüldü' : '5 yeni kelime',
                      onTap: yeni == 0 ? null : () => _kategoriSec(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BaslatKarti(
                      ikon: Icons.replay,
                      baslik: 'Tekrar et',
                      alt: due == 0 ? 'Tekrar yok' : '$due kelime',
                      onTap: due == 0
                          ? null
                          : () => _ac(context, due: true, yeniSayi: 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _BaslatKarti(
                ikon: Icons.menu_book_outlined,
                baslik: 'Kelime listesi',
                alt: 'Ara, kategoriye göre gez, dinle',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WordBrowser()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _ac(
    BuildContext context, {
    required bool due,
    required int yeniSayi,
    String? cat,
  }) {
    final s = Store.i;
    final c = Content.i;
    final tekrar = due ? s.dueWords(c).take(12).toList() : <Word>[];
    final yeni = yeniSayi > 0 ? s.newWords(c, yeniSayi, cat: cat) : <Word>[];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordSession(review: tekrar, fresh: yeni),
      ),
    );
  }

  void _kategoriSec(BuildContext context) {
    final c = Content.i;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Hangi alandan öğrenmek istersin?'),
            ),
            ListTile(
              leading: const Icon(Icons.shuffle),
              title: const Text('Karışık'),
              onTap: () {
                Navigator.pop(ctx);
                _ac(context, due: false, yeniSayi: 5);
              },
            ),
            for (final k in c.categories)
              Builder(
                builder: (_) {
                  final kalan = c.words
                      .where(
                        (w) => w.cat == k.id && Store.i.words[w.id] == null,
                      )
                      .length;
                  return ListTile(
                    title: Text(k.name),
                    subtitle: Text('$kalan yeni kelime kaldı'),
                    enabled: kalan > 0,
                    onTap: () {
                      Navigator.pop(ctx);
                      _ac(context, due: false, yeniSayi: 5, cat: k.id);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Cubuk extends StatelessWidget {
  final int yeni, ogreniliyor, ustalasan;
  const _Cubuk({
    required this.yeni,
    required this.ogreniliyor,
    required this.ustalasan,
  });
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final toplam = max(1, yeni + ogreniliyor + ustalasan);
    Widget parca(int n, Color c) => n == 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: n,
            child: Container(height: 12, color: c),
          );
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              parca(ustalasan, Colors.green),
              parca(ogreniliyor, Colors.orange),
              parca(yeni, t.colorScheme.surfaceContainerHighest),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Etiket(Colors.green, 'Ustalaşılan', ustalasan),
            _Etiket(Colors.orange, 'Öğreniliyor', ogreniliyor),
            _Etiket(t.colorScheme.outline, 'Yeni', yeni),
          ],
        ),
        if (toplam == 0) const SizedBox.shrink(),
      ],
    );
  }
}

class _Etiket extends StatelessWidget {
  final Color renk;
  final String ad;
  final int n;
  const _Etiket(this.renk, this.ad, this.n);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text('$ad $n', style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}

class _BaslatKarti extends StatelessWidget {
  final IconData ikon;
  final String baslik, alt;
  final VoidCallback? onTap;
  final bool vurgulu;
  const _BaslatKarti({
    required this.ikon,
    required this.baslik,
    required this.alt,
    this.onTap,
    this.vurgulu = false,
  });
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final fg = vurgulu ? t.colorScheme.onPrimary : t.colorScheme.onSurface;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: AppCard(
        color: vurgulu ? t.colorScheme.primary : null,
        onTap: onTap,
        child: Row(
          children: [
            Icon(ikon, color: fg, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baslik,
                    style: t.textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    alt,
                    style: t.textTheme.bodySmall?.copyWith(
                      color: fg.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alıştırma oturumu
// ---------------------------------------------------------------------------

enum ExType { intro, termToTr, trToTerm, cloze, dictation, flash }

class Ex {
  final Word word;
  final ExType type;
  final bool retry; // aynı oturumda yanlış yapılınca tekrar: puanlanmaz
  Ex(this.word, this.type, {this.retry = false});
}

/// Bir kelimenin kutusuna göre uygun alıştırma türünü seçer.
ExType alistirmaTuru(Word w, WordState? s, Random r, {bool sesVar = true}) {
  final kutu = s?.box ?? 0;
  final adaylar = <ExType>[ExType.termToTr];
  if (kutu >= 1) {
    adaylar.add(ExType.trToTerm);
    if (w.hasCloze) adaylar.add(ExType.cloze);
  }
  if (kutu >= 2 && sesVar) adaylar.add(ExType.dictation);
  if (kutu >= 3) adaylar.add(ExType.flash);
  return adaylar[r.nextInt(adaylar.length)];
}

class WordSession extends StatefulWidget {
  final List<Word> review, fresh;
  const WordSession({super.key, required this.review, required this.fresh});
  @override
  State<WordSession> createState() => _WordSessionState();
}

class _WordSessionState extends State<WordSession> {
  final _r = Random();
  late List<Ex> _kuyruk;
  int _i = 0;
  int _dogru = 0, _yanlis = 0, _xp = 0;
  final Set<String> _puanlanan = {};
  final Set<String> _ogrenilen = {};

  // geçerli alıştırmanın durumu
  int? _secim;
  int? _dogruIndeks;
  List<String> _secenekler = [];
  bool? _sonuc; // null: cevaplanmadı
  bool _cevapGoster = false; // flash kartlar için
  final _yazi = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = Store.i;
    _kuyruk = [];
    for (final w in widget.review) {
      _kuyruk.add(Ex(w, alistirmaTuru(w, s.words[w.id], _r)));
    }
    // yeni kelimeler: 3'erli gruplar halinde önce tanıt, sonra sor
    for (var i = 0; i < widget.fresh.length; i += 3) {
      final grup = widget.fresh.skip(i).take(3).toList();
      for (final w in grup) {
        _kuyruk.add(Ex(w, ExType.intro));
      }
      for (final w in grup) {
        _kuyruk.add(Ex(w, ExType.termToTr));
      }
    }
    _hazirla();
  }

  @override
  void dispose() {
    _yazi.dispose();
    Tts.i.stop();
    super.dispose();
  }

  Ex get _ex => _kuyruk[_i];

  List<Word> _celdiriciler(Word w, int n) {
    final c = Content.i.words.where((x) => x.id != w.id).toList()..shuffle(_r);
    // aynı kategori ve aynı türden olanlar önce (daha zor, daha öğretici)
    c.sort((a, b) {
      int p(Word x) => (x.cat == w.cat ? 0 : 2) + (x.pos == w.pos ? 0 : 1);
      return p(a).compareTo(p(b));
    });
    final sonuc = <Word>[];
    for (final x in c) {
      if (sonuc.length == n) break;
      if (sonuc.any((y) => y.tr == x.tr || y.term == x.term)) continue;
      if (x.tr == w.tr) continue;
      sonuc.add(x);
    }
    return sonuc;
  }

  void _hazirla() {
    _secim = null;
    _sonuc = null;
    _cevapGoster = false;
    _yazi.clear();
    final e = _ex;
    final w = e.word;
    switch (e.type) {
      case ExType.termToTr:
        final d = _celdiriciler(w, 3);
        final tum = [w.tr, ...d.map((x) => x.tr)]..shuffle(_r);
        _secenekler = tum;
        _dogruIndeks = tum.indexOf(w.tr);
        break;
      case ExType.trToTerm:
        final d = _celdiriciler(w, 3);
        final tum = [w.term, ...d.map((x) => x.term)]..shuffle(_r);
        _secenekler = tum;
        _dogruIndeks = tum.indexOf(w.term);
        break;
      case ExType.cloze:
        final d = _celdiriciler(w, 3);
        final tum = [w.term, ...d.map((x) => x.term)]..shuffle(_r);
        _secenekler = tum;
        _dogruIndeks = tum.indexOf(w.term);
        break;
      default:
        _secenekler = [];
        _dogruIndeks = null;
    }
    if (e.type == ExType.dictation) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Tts.i.speak(w.term, yavas: true),
      );
    }
    if (e.type == ExType.intro) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Tts.i.speak(w.term));
    }
  }

  Future<void> _degerlendir(bool dogru) async {
    final e = _ex;
    setState(() => _sonuc = dogru);
    if (dogru) {
      _dogru++;
    } else {
      _yanlis++;
    }
    if (!e.retry && !_puanlanan.contains(e.word.id)) {
      _puanlanan.add(e.word.id);
      await Store.i.grade(e.word.id, dogru);
      if (dogru) {
        _xp += 10;
        await Store.i.addXp(10);
        if (e.type == ExType.termToTr && widget.fresh.contains(e.word)) {
          _ogrenilen.add(e.word.id);
        }
      }
    }
    if (!dogru) {
      // 4 sıra sonra bir kez daha sor (puanlanmaz)
      final yer = min(_kuyruk.length, _i + 5);
      _kuyruk.insert(yer, Ex(e.word, ExType.termToTr, retry: true));
    }
  }

  void _sonraki() {
    if (_i + 1 >= _kuyruk.length) {
      setState(() => _i = _kuyruk.length); // bitti
      return;
    }
    setState(() {
      _i++;
      _hazirla();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final bitti = _i >= _kuyruk.length;
    return Scaffold(
      appBar: AppBar(
        title: bitti
            ? const Text('Özet')
            : Text('${_i + 1} / ${_kuyruk.length}'),
        bottom: bitti
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: _i / _kuyruk.length),
              ),
      ),
      body: bitti ? _ozet(t) : _govde(t),
    );
  }

  Widget _ozet(ThemeData t) {
    final toplam = _dogru + _yanlis;
    final yuzde = toplam == 0 ? 0 : (_dogru * 100 / toplam).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ring(value: yuzde / 100, label: '%$yuzde', sub: 'doğru', size: 140),
            const SizedBox(height: 24),
            Text('+$_xp XP', style: t.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _ogrenilen.isEmpty
                  ? 'Tekrarlar tamamlandı.'
                  : '${_ogrenilen.length} yeni kelime öğrendin.',
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _govde(ThemeData t) {
    final e = _ex;
    final w = e.word;
    Widget icerik;
    switch (e.type) {
      case ExType.intro:
        icerik = _intro(t, w);
        break;
      case ExType.termToTr:
        icerik = _soru(
          t,
          'Bu kelimenin Türkçesi nedir?',
          w.term,
          seslendir: w.term,
          ipucu: w.pos,
        );
        break;
      case ExType.trToTerm:
        icerik = _soru(t, 'Hangi İngilizce kelime?', w.tr, ipucu: w.def);
        break;
      case ExType.cloze:
        icerik = _soru(t, 'Boşluğa hangisi gelir?', w.clozeText, kucuk: true);
        break;
      case ExType.dictation:
        icerik = _dikte(t, w);
        break;
      case ExType.flash:
        icerik = _flash(t, w);
        break;
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [icerik],
          ),
        ),
        if (_sonuc != null && e.type != ExType.intro)
          FeedbackBar(
            correct: _sonuc!,
            title: _sonuc! ? 'Doğru!' : 'Doğrusu: ${_dogruMetni(w)}',
            detail: '${w.term} (${w.pos}) = ${w.tr}\n${w.def}\n“${w.ex}”',
            onNext: _sonraki,
          ),
      ],
    );
  }

  String _dogruMetni(Word w) {
    switch (_ex.type) {
      case ExType.termToTr:
        return w.tr;
      default:
        return w.term;
    }
  }

  Widget _intro(ThemeData t, Word w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip(label: Text(Content.i.categoryName(w.cat))),
            const Spacer(),
            Text(
              'Yeni kelime',
              style: t.textTheme.labelLarge?.copyWith(
                color: t.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      w.term,
                      style: t.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SpeakButton(w.term, tonal: true),
                ],
              ),
              Text(
                w.pos,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 28),
              Text(
                w.tr,
                style: t.textTheme.headlineSmall?.copyWith(
                  color: t.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(w.def, style: t.textTheme.bodyLarge),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '“${w.ex}”',
                      style: t.textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  SpeakButton(w.ex),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              await Store.i.addXp(2);
              _sonraki();
            },
            child: const Text('Anladım'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () async {
              await Store.i.markKnown(w.id);
              // bu kelimeyi sorulardan çıkar (sorular tanıtımdan sonra geldiği için sıra kaymaz)
              _kuyruk.removeWhere(
                (x) => x.word.id == w.id && x.type != ExType.intro,
              );
              _sonraki();
            },
            child: const Text('Bu kelimeyi zaten biliyorum'),
          ),
        ),
      ],
    );
  }

  Widget _soru(
    ThemeData t,
    String yonerge,
    String soru, {
    String? seslendir,
    String? ipucu,
    bool kucuk = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          yonerge,
          style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                soru,
                style:
                    (kucuk
                            ? t.textTheme.titleLarge
                            : t.textTheme.headlineMedium)
                        ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (seslendir != null) SpeakButton(seslendir, tonal: true),
          ],
        ),
        if (ipucu != null && !kucuk)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              ipucu,
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 22),
        ChoiceList(
          options: _secenekler,
          selected: _secim,
          correct: _sonuc == null ? null : _dogruIndeks,
          onSelect: (i) {
            setState(() => _secim = i);
            _degerlendir(i == _dogruIndeks);
          },
        ),
      ],
    );
  }

  Widget _dikte(ThemeData t, Word w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dinle ve yaz',
          style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            SpeakButton(w.term, tonal: true, size: 32),
            const SizedBox(width: 8),
            SpeakButton(w.term, yavas: true, tonal: true, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text(w.tr, style: t.textTheme.titleMedium)),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _yazi,
          enabled: _sonuc == null,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Duyduğun kelimeyi yaz',
          ),
          onSubmitted: (_) {
            if (_sonuc == null) _degerlendir(typedMatches(_yazi.text, w.term));
          },
        ),
        const SizedBox(height: 12),
        if (_sonuc == null)
          FilledButton(
            onPressed: () => _degerlendir(typedMatches(_yazi.text, w.term)),
            child: const Text('Kontrol et'),
          ),
      ],
    );
  }

  Widget _flash(ThemeData t, Word w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hatırla',
          style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                w.term,
                style: t.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SpeakButton(w.term, tonal: true),
          ],
        ),
        const SizedBox(height: 18),
        if (!_cevapGoster)
          FilledButton.tonal(
            onPressed: () => setState(() => _cevapGoster = true),
            child: const Text('Cevabı göster'),
          )
        else ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w.tr,
                  style: t.textTheme.titleLarge?.copyWith(
                    color: t.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(w.def),
                const SizedBox(height: 8),
                Text(
                  '“${w.ex}”',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_sonuc == null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _degerlendir(false),
                    child: const Text('Hatırlamadım'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _degerlendir(true),
                    child: const Text('Hatırladım'),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kelime listesi
// ---------------------------------------------------------------------------

class WordBrowser extends StatefulWidget {
  const WordBrowser({super.key});
  @override
  State<WordBrowser> createState() => _WordBrowserState();
}

class _WordBrowserState extends State<WordBrowser> {
  String _q = '';
  String? _cat;

  @override
  Widget build(BuildContext context) {
    final c = Content.i;
    final q = _q.trim().toLowerCase();
    final liste = c.words.where((w) {
      if (_cat != null && w.cat != _cat) return false;
      if (q.isEmpty) return true;
      return w.term.toLowerCase().contains(q) ||
          w.tr.toLowerCase().contains(q) ||
          w.def.toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Kelime listesi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'İngilizce ya da Türkçe ara',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: ChoiceChip(
                    label: const Text('Hepsi'),
                    selected: _cat == null,
                    onSelected: (_) => setState(() => _cat = null),
                  ),
                ),
                for (final k in c.categories)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: ChoiceChip(
                      label: Text(k.name),
                      selected: _cat == k.id,
                      onSelected: (_) => setState(() => _cat = k.id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Store.i,
              builder: (context, _) => ListView.builder(
                itemCount: liste.length,
                itemBuilder: (context, i) {
                  final w = liste[i];
                  final s = Store.i.words[w.id];
                  return ListTile(
                    title: Text(
                      w.term,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${w.pos} · ${w.tr}'),
                    trailing: s == null
                        ? null
                        : Icon(
                            s.box >= 4 ? Icons.verified : Icons.timelapse,
                            color: s.box >= 4 ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                    onTap: () => _detay(context, w),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _detay(BuildContext context, Word w) {
    final t = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
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
                      w.term,
                      style: t.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SpeakButton(w.term, tonal: true),
                ],
              ),
              Text(
                '${w.pos} · ${Content.i.categoryName(w.cat)}',
                style: t.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                w.tr,
                style: t.textTheme.titleLarge?.copyWith(
                  color: t.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(w.def),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '“${w.ex}”',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  SpeakButton(w.ex),
                ],
              ),
              const SizedBox(height: 12),
              if (Store.i.words[w.id] == null)
                OutlinedButton(
                  onPressed: () async {
                    await Store.i.markKnown(w.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Bunu zaten biliyorum'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

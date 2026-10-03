import 'dart:math';

import 'package:flutter/material.dart';

import '../data.dart';
import '../speech.dart';
import '../store.dart';
import '../text_utils.dart';
import '../widgets.dart';

/// Mikrofon oturumu: canlı metni tutar. Konuşma tanıma yoksa [desteklenmiyor] true olur.
class Recorder extends ChangeNotifier {
  String text = '';
  bool listening = false;
  bool finished = false;
  bool unsupported = false;
  bool starting = false; // mikrofon/izin hazırlanıyor
  String? message; // kullanıcıya gösterilecek durum/hata
  String? error;
  bool _disposed = false;

  Recorder() {
    Stt.i.dinliyor.addListener(_durumDegisti);
  }

  void _durumDegisti() {
    if (!Stt.i.dinliyor.value && listening) {
      listening = false;
      finished = text.trim().isNotEmpty;
      if (!finished) message = _mesaj();
      if (!_disposed) notifyListeners();
    }
  }

  /// Hiç metin gelmeden bittiyse nedenini kullanıcıya açıkla.
  String _mesaj() {
    final h = Stt.i.sonHata ?? '';
    if (h.contains('permission') ||
        h.contains('not-allowed') ||
        h.contains('denied')) {
      return 'Mikrofon izni verilmemiş. Tarayıcı/telefon ayarlarından izin ver.';
    }
    if (h.isEmpty ||
        h.contains('no_match') ||
        h.contains('timeout') ||
        h.contains('no-speech')) {
      return 'Bir şey duyamadım. Mikrofona yakın ve net konuşup tekrar dene.';
    }
    return 'Ses alınamadı ($h). Mikrofon iznini kontrol et.';
  }

  Future<void> start({
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    text = '';
    finished = false;
    error = null;
    unsupported = false;
    message = null;
    starting = true;
    notifyListeners();
    final ok = await Stt.i.start(
      listenFor: listenFor,
      pauseFor: pauseFor,
      onResult: (t, son) {
        text = t;
        if (son) {
          listening = false;
          finished = t.trim().isNotEmpty;
          if (!finished) message = _mesaj();
        }
        if (!_disposed) notifyListeners();
      },
    );
    starting = false;
    if (!ok) {
      unsupported = !Stt.i.available;
      error = Stt.i.sonHata;
      listening = false;
    } else {
      listening = true;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> stop() async {
    await Stt.i.stop();
    listening = false;
    finished = text.trim().isNotEmpty;
    if (!_disposed) notifyListeners();
  }

  void reset() {
    text = '';
    finished = false;
    error = null;
    message = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    Stt.i.dinliyor.removeListener(_durumDegisti);
    Stt.i.cancel();
    super.dispose();
  }
}

/// Büyük mikrofon düğmesi: hazırlanıyor / dinliyor / hata mesajı durumlarını gösterir.
class MicButton extends StatelessWidget {
  final Recorder rec;
  final VoidCallback onStart;
  const MicButton({super.key, required this.rec, required this.onStart});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dinliyor = rec.listening;
    final renk = dinliyor ? Colors.red : t.colorScheme.primary;
    return Column(
      children: [
        GestureDetector(
          onTap: rec.starting ? null : (dinliyor ? rec.stop : onStart),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: dinliyor ? 96 : 84,
            height: dinliyor ? 96 : 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: renk,
              boxShadow: [
                BoxShadow(
                  color: renk.withValues(alpha: 0.35),
                  blurRadius: dinliyor ? 24 : 10,
                  spreadRadius: dinliyor ? 6 : 0,
                ),
              ],
            ),
            child: rec.starting
                ? const Padding(
                    padding: EdgeInsets.all(26),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    dinliyor ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        if (rec.message != null && !dinliyor && !rec.starting)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              rec.message!,
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium?.copyWith(
                color: Colors.orange.shade700,
              ),
            ),
          ),
        Text(
          rec.starting
              ? 'Mikrofon hazırlanıyor… izin sorarsa onayla'
              : dinliyor
              ? 'Dinliyorum… bitince dokun'
              : 'Konuşmak için dokun',
          style: t.textTheme.labelLarge,
        ),
      ],
    );
  }
}

class UnsupportedNote extends StatelessWidget {
  final String? error;
  const UnsupportedNote({super.key, this.error});
  @override
  Widget build(BuildContext context) => AppCard(
    color: Colors.orange.withValues(alpha: 0.12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.mic_off, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Konuşma tanıma kullanılamıyor',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'iPhone/Android: Ayarlar’dan uygulamaya Mikrofon ve Konuşma Tanıma izni ver. '
          'Web: Chrome (veya Safari) kullan ve mikrofon iznini onayla. '
          'Şimdilik cevabını yazarak ya da kendini değerlendirerek devam edebilirsin.',
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text('Ayrıntı: $error', style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}

// ---------------------------------------------------------------------------

class SpeakingPage extends StatelessWidget {
  const SpeakingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget kart(
      IconData ikon,
      String baslik,
      String alt,
      Widget sayfa, {
      bool vurgulu = false,
    }) {
      final fg = vurgulu ? t.colorScheme.onPrimary : t.colorScheme.onSurface;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          color: vurgulu ? t.colorScheme.primary : null,
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => sayfa)),
          child: Row(
            children: [
              Icon(ikon, size: 30, color: fg),
              const SizedBox(width: 14),
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
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Konuşma')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          kart(
            Icons.record_voice_over,
            'Cümle oku',
            'Cümleyi dinle, yüksek sesle oku, puanını gör',
            const ReadAloudPage(),
            vurgulu: true,
          ),
          kart(
            Icons.forum_outlined,
            'Soruya sesli cevap ver',
            'Mülakat ve günlük iş soruları, ${Content.i.prompts.length} soru',
            const PromptListPage(),
          ),
          kart(
            Icons.spatial_audio_off,
            'Telaffuz',
            'Zor teknik kelimeler: IPA, ipucu, kontrol',
            const PronunciationPage(),
          ),
          const SizedBox(height: 8),
          Text(
            'Not: Konuşma tanıma bazen yanlış duyabilir. Puanı kesin bir ölçü değil, çalışma rehberi olarak kullan.',
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cümle okuma
// ---------------------------------------------------------------------------

class ReadAloudPage extends StatefulWidget {
  const ReadAloudPage({super.key});
  @override
  State<ReadAloudPage> createState() => _ReadAloudPageState();
}

class _ReadAloudPageState extends State<ReadAloudPage> {
  final _r = Random();
  final _rec = Recorder();
  String? _seviye;
  late List<Sentence> _sira;
  int _i = 0;
  WordAlignment? _sonuc;
  bool _cevir = false;
  bool _puanlandi = false;

  @override
  void initState() {
    super.initState();
    _karistir();
    _rec.addListener(_dinle);
  }

  void _karistir() {
    final l =
        Content.i.sentences
            .where((s) => _seviye == null || s.level == _seviye)
            .toList()
          ..shuffle(_r);
    _sira = l;
    _i = 0;
    _sonuc = null;
    _cevir = false;
    _puanlandi = false;
  }

  void _dinle() {
    if (_rec.finished && _sonuc == null && !_rec.listening) {
      _degerlendir(_rec.text);
    }
    if (mounted) setState(() {});
  }

  Future<void> _degerlendir(String metin) async {
    final a = align(_sira[_i].text, metin);
    setState(() => _sonuc = a);
    if (!_puanlandi && a.percent >= 60) {
      _puanlandi = true;
      await Store.i.markSpeaking();
      await Store.i.addXp(5 + a.percent ~/ 20);
    }
  }

  @override
  void dispose() {
    _rec.removeListener(_dinle);
    _rec.dispose();
    Tts.i.stop();
    super.dispose();
  }

  void _sonraki() {
    setState(() {
      _i = (_i + 1) % _sira.length;
      _sonuc = null;
      _cevir = false;
      _puanlandi = false;
      _rec.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = _sira[_i];
    return Scaffold(
      appBar: AppBar(title: const Text('Cümle oku')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final v in const [null, 'A2', 'B1', 'B2'])
                ChoiceChip(
                  label: Text(v ?? 'Karışık'),
                  selected: _seviye == v,
                  onSelected: (_) => setState(() {
                    _seviye = v;
                    _rec.reset();
                    _karistir();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LevelChip(s.level),
                    const Spacer(),
                    SpeakButton(s.text, tonal: true),
                    SpeakButton(s.text, yavas: true, tonal: true),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s.text,
                  style: t.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                if (_cevir)
                  Text(
                    s.tr,
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: t.colorScheme.primary,
                    ),
                  )
                else
                  TextButton(
                    onPressed: () => setState(() => _cevir = true),
                    child: const Text('Türkçesini göster'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (_rec.unsupported)
            Column(
              children: [
                UnsupportedNote(error: _rec.error),
                const SizedBox(height: 14),
                if (_sonuc == null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _sonuc = align(s.text, '')),
                          child: const Text('Zorlandım'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            setState(() => _sonuc = align(s.text, s.text));
                            if (!_puanlandi) {
                              _puanlandi = true;
                              await Store.i.markSpeaking();
                              await Store.i.addXp(3);
                            }
                          },
                          child: const Text('İyi okudum'),
                        ),
                      ),
                    ],
                  ),
              ],
            )
          else
            Center(
              child: MicButton(
                rec: _rec,
                onStart: () => _rec.start(
                  listenFor: const Duration(seconds: 25),
                  pauseFor: const Duration(seconds: 2),
                ),
              ),
            ),
          if (_rec.text.isNotEmpty && _sonuc == null) ...[
            const SizedBox(height: 16),
            Text(
              '“${_rec.text}”',
              textAlign: TextAlign.center,
              style: t.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (_sonuc != null && !_rec.unsupported) ...[
            const SizedBox(height: 22),
            Center(
              child: Ring(
                value: _sonuc!.accuracy,
                label: '%${_sonuc!.percent}',
                sub: _sonuc!.percent >= 85
                    ? 'çok iyi'
                    : _sonuc!.percent >= 60
                    ? 'iyi'
                    : 'tekrar dene',
              ),
            ),
            const SizedBox(height: 16),
            WordChips(words: _sonuc!.targetWords, hit: _sonuc!.hit),
            if (_rec.text.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Duyduğum: “${_rec.text}”',
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Kırmızı sözcükleri tekrar dinle ve yavaşça söyle.',
              style: t.textTheme.bodySmall,
            ),
          ],
          if (_sonuc != null || _rec.finished) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _sonuc = null;
                      _puanlandi = false;
                      _rec.reset();
                    }),
                    child: const Text('Tekrar dene'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _sonraki,
                    child: const Text('Sonraki cümle'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Soruya sesli cevap
// ---------------------------------------------------------------------------

class PromptListPage extends StatelessWidget {
  const PromptListPage({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sesli cevap soruları')),
      body: ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final p in Content.i.prompts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AnswerPage(p: p)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.question,
                              style: t.textTheme.bodyLarge,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                LevelChip(p.level),
                                if (Store.i.best['spk:${p.id}'] != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'en iyi %${Store.i.best['spk:${p.id}']}',
                                    style: t.textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
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

class AnswerPage extends StatefulWidget {
  final SpeakPrompt p;
  const AnswerPage({super.key, required this.p});
  @override
  State<AnswerPage> createState() => _AnswerPageState();
}

class _AnswerPageState extends State<AnswerPage> {
  final _rec = Recorder();
  final _yazi = TextEditingController();
  bool _yazarak = false;
  bool _degerlendi = false;
  Map<String, bool> _kelimeler = {};
  int _puan = 0;
  int _sozcuk = 0;

  @override
  void initState() {
    super.initState();
    _rec.addListener(_dinle);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Tts.i.speak(widget.p.question),
    );
  }

  void _dinle() {
    if (_rec.finished && !_degerlendi && !_rec.listening) {
      _degerlendir(_rec.text);
    }
    if (mounted) setState(() {});
  }

  Future<void> _degerlendir(String metin) async {
    final hits = keywordHits(metin, widget.p.keywords);
    final kapsam =
        hits.values.where((v) => v).length / widget.p.keywords.length;
    final n = tokenize(metin).length;
    final uzunluk = min(1.0, n / 35);
    final puan = ((kapsam * 0.7 + uzunluk * 0.3) * 100).round();
    setState(() {
      _kelimeler = hits;
      _sozcuk = n;
      _puan = puan;
      _degerlendi = true;
    });
    await Store.i.saveBest('spk:${widget.p.id}', puan);
    if (n >= 8) {
      await Store.i.markSpeaking();
      await Store.i.addXp(10 + puan ~/ 10);
    }
  }

  @override
  void dispose() {
    _rec.removeListener(_dinle);
    _rec.dispose();
    _yazi.dispose();
    Tts.i.stop();
    super.dispose();
  }

  void _tekrar() => setState(() {
    _degerlendi = false;
    _rec.reset();
    _yazi.clear();
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = widget.p;
    final metin = _yazarak ? _yazi.text : _rec.text;
    return Scaffold(
      appBar: AppBar(title: const Text('Sesli cevap')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LevelChip(p.level),
                    const Spacer(),
                    SpeakButton(p.question, tonal: true),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  p.question,
                  style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'İpucu: ${p.tip}',
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!_degerlendi) ...[
            if (_rec.unsupported && !_yazarak)
              UnsupportedNote(error: _rec.error),
            if (!_yazarak && !_rec.unsupported)
              Center(
                child: MicButton(
                  rec: _rec,
                  onStart: () => _rec.start(
                    listenFor: const Duration(seconds: 90),
                    pauseFor: const Duration(seconds: 4),
                  ),
                ),
              ),
            if (_rec.text.isNotEmpty && !_yazarak) ...[
              const SizedBox(height: 14),
              Text(
                '“${_rec.text}”',
                style: t.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (!_rec.listening && !_rec.finished)
                TextButton(
                  onPressed: () => _degerlendir(_rec.text),
                  child: const Text('Değerlendir'),
                ),
            ],
            if (_yazarak || _rec.unsupported) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _yazi,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Cevabını İngilizce yaz',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _yazi.text.trim().isEmpty
                    ? null
                    : () {
                        _yazarak = true;
                        _degerlendir(_yazi.text);
                      },
                child: const Text('Değerlendir'),
              ),
            ],
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _yazarak = !_yazarak),
                child: Text(_yazarak ? 'Konuşarak cevapla' : 'Yazarak cevapla'),
              ),
            ),
          ] else ...[
            Center(
              child: Ring(
                value: _puan / 100,
                label: '%$_puan',
                sub: '$_sozcuk sözcük',
              ),
            ),
            const SizedBox(height: 16),
            Text('Anahtar sözcükler', style: t.textTheme.titleSmall),
            const SizedBox(height: 8),
            WordChips(
              words: _kelimeler.keys.toList(),
              hit: _kelimeler.values.toList(),
            ),
            const SizedBox(height: 6),
            Text(
              _sozcuk < 25
                  ? 'Cevabın biraz kısa. Bir örnek ya da sebep ekleyerek 3-4 cümleye çıkar.'
                  : 'Uzunluk iyi. Şimdi örnek cevapla karşılaştır.',
              style: t.textTheme.bodySmall,
            ),
            if (metin.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Senin cevabın', style: t.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(metin),
            ],
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Örnek cevap',
                          style: t.textTheme.titleSmall,
                        ),
                      ),
                      SpeakButton(p.model, tonal: true),
                      SpeakButton(p.model, yavas: true, tonal: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(p.model, style: t.textTheme.bodyLarge),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _tekrar,
                    child: const Text('Tekrar dene'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Listeye dön'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Telaffuz
// ---------------------------------------------------------------------------

class PronunciationPage extends StatefulWidget {
  const PronunciationPage({super.key});
  @override
  State<PronunciationPage> createState() => _PronunciationPageState();
}

class _PronunciationPageState extends State<PronunciationPage> {
  final _rec = Recorder();
  late final List<PronWord> _liste;
  int _i = 0;
  bool? _dogru;
  int _dogruSayisi = 0;

  @override
  void initState() {
    super.initState();
    _liste = List.of(Content.i.pron)..shuffle(Random());
    _rec.addListener(_dinle);
  }

  void _dinle() {
    if (_rec.finished && _dogru == null && !_rec.listening) _kontrol(_rec.text);
    if (mounted) setState(() {});
  }

  Future<void> _kontrol(String metin) async {
    final hedef = _liste[_i].word.toLowerCase();
    final tokens = tokenize(metin);
    final ok =
        tokens.any(
          (w) =>
              w == hedef ||
              levenshtein(w, hedef) <= (hedef.length >= 8 ? 2 : 1),
        ) ||
        tokens.join('').contains(hedef);
    setState(() => _dogru = ok);
    if (ok) {
      _dogruSayisi++;
      await Store.i.addXp(3);
      if (_dogruSayisi % 5 == 0) await Store.i.markSpeaking();
    }
  }

  void _git(int d) => setState(() {
    _i = (_i + d) % _liste.length;
    _dogru = null;
    _rec.reset();
  });

  @override
  void dispose() {
    _rec.removeListener(_dinle);
    _rec.dispose();
    Tts.i.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final w = _liste[_i];
    return Scaffold(
      appBar: AppBar(title: Text('Telaffuz ${_i + 1}/${_liste.length}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  w.word,
                  style: t.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  w.ipa,
                  style: t.textTheme.titleLarge?.copyWith(
                    color: t.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SpeakButton(w.word, tonal: true, size: 30),
                    const SizedBox(width: 12),
                    SpeakButton(w.word, yavas: true, tonal: true, size: 30),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  w.tip,
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_rec.unsupported)
            UnsupportedNote(error: _rec.error)
          else
            Center(
              child: MicButton(
                rec: _rec,
                onStart: () => _rec.start(
                  listenFor: const Duration(seconds: 8),
                  pauseFor: const Duration(seconds: 2),
                ),
              ),
            ),
          if (_rec.text.isNotEmpty || _dogru != null) ...[
            const SizedBox(height: 16),
            AppCard(
              color: (_dogru == true ? Colors.green : Colors.orange).withValues(
                alpha: 0.14,
              ),
              child: Row(
                children: [
                  Icon(
                    _dogru == true ? Icons.check_circle : Icons.info_outline,
                    color: _dogru == true ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dogru == true
                          ? 'Güzel! “${_rec.text}” olarak anlaşıldı.'
                          : _dogru == false
                          ? 'Ben “${_rec.text}” duydum. Dinleyip bir daha dene.'
                          : '“${_rec.text}”',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _git(-1),
                  child: const Text('Önceki'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _git(1),
                  child: const Text('Sonraki'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

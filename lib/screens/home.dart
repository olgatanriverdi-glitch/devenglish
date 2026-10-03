import 'dart:math';

import 'package:flutter/material.dart';

import '../data.dart';
import '../speech.dart';
import '../store.dart';
import '../widgets.dart';
import 'words.dart';

class HomePage extends StatelessWidget {
  final void Function(int tab) onGo;
  const HomePage({super.key, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = Content.i;
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        final bugun = s.todayStats;
        final due = s.dueWords(c).length;
        final yeni = s.newRemaining(c);
        final gununKelimesi = c.words[(s.today * 7) % c.words.length];
        return Scaffold(
          appBar: AppBar(
            title: const Text('DevEnglish'),
            actions: [
              IconButton(
                tooltip: 'Ayarlar',
                onPressed: () => _ayarlar(context),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Istatistik(
                      ikon: Icons.local_fire_department,
                      renk: Colors.deepOrange,
                      deger: '${s.streak}',
                      etiket: 'gün seri',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Istatistik(
                      ikon: Icons.bolt,
                      renk: Colors.amber.shade700,
                      deger: '${s.totalXp}',
                      etiket: 'XP',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Istatistik(
                      ikon: Icons.school,
                      renk: Colors.green,
                      deger: '${s.learnedCount}',
                      etiket: 'kelime',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Row(
                  children: [
                    Ring(
                      value: bugun.words / s.dailyGoal,
                      label: '${bugun.words}',
                      sub: '/ ${s.dailyGoal} kelime',
                      size: 100,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bugünkü hedef', style: t.textTheme.titleMedium),
                          const SizedBox(height: 10),
                          _Gorev(
                            Icons.hearing,
                            'Dinleme',
                            bugun.listening >= 1,
                          ),
                          _Gorev(Icons.mic, 'Konuşma', bugun.speaking >= 1),
                          _Gorev(Icons.menu_book, 'Okuma', bugun.reading >= 1),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                color: t.colorScheme.primary,
                onTap: () {
                  if (due + min(5, yeni) > 0) {
                    final tekrar = s.dueWords(c).take(12).toList();
                    final yeniler = s.newWords(c, 5);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            WordSession(review: tekrar, fresh: yeniler),
                      ),
                    );
                  } else {
                    onGo(1);
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.play_circle_fill,
                      color: t.colorScheme.onPrimary,
                      size: 36,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Günlük çalışmaya başla',
                            style: t.textTheme.titleMedium?.copyWith(
                              color: t.colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            due + min(5, yeni) == 0
                                ? 'Kelime çalışması bitti. Dinleme veya konuşma yap.'
                                : '$due tekrar · ${min(5, yeni)} yeni kelime',
                            style: t.textTheme.bodySmall?.copyWith(
                              color: t.colorScheme.onPrimary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Kisayol(Icons.hearing, 'Dinle', () => onGo(2)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _Kisayol(Icons.mic, 'Konuş', () => onGo(3))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Kisayol(Icons.menu_book, 'Oku', () => onGo(4)),
                  ),
                ],
              ),
              const SectionTitle('Günün kelimesi'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            gununKelimesi.term,
                            style: t.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SpeakButton(gununKelimesi.term, tonal: true),
                      ],
                    ),
                    Text(
                      '${gununKelimesi.pos} · ${c.categoryName(gununKelimesi.cat)}',
                      style: t.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      gununKelimesi.tr,
                      style: t.textTheme.titleMedium?.copyWith(
                        color: t.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(gununKelimesi.def),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '“${gununKelimesi.ex}”',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                        SpeakButton(gununKelimesi.ex),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionTitle('Son 7 gün (XP)'),
              AppCard(child: _Grafik(deger: s.lastDaysXp(7))),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _ayarlar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const _Ayarlar(),
    );
  }
}

class _Istatistik extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final String deger, etiket;
  const _Istatistik({
    required this.ikon,
    required this.renk,
    required this.deger,
    required this.etiket,
  });
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Icon(ikon, color: renk),
          const SizedBox(height: 4),
          Text(
            deger,
            style: t.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(etiket, style: t.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _Gorev extends StatelessWidget {
  final IconData ikon;
  final String ad;
  final bool tamam;
  const _Gorev(this.ikon, this.ad, this.tamam);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(
          tamam ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 20,
          color: tamam ? Colors.green : Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Icon(ikon, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

class _Kisayol extends StatelessWidget {
  final IconData ikon;
  final String ad;
  final VoidCallback onTap;
  const _Kisayol(this.ikon, this.ad, this.onTap);
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        Icon(ikon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 6),
        Text(ad, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

class _Grafik extends StatelessWidget {
  final List<int> deger;
  const _Grafik({required this.deger});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final en = max(1, deger.reduce(max));
    const gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final bugun = DateTime.now();
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < deger.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    deger[i] == 0 ? '' : '${deger[i]}',
                    style: t.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    height: max(4, 70.0 * deger[i] / en),
                    decoration: BoxDecoration(
                      color: i == deger.length - 1
                          ? t.colorScheme.primary
                          : t.colorScheme.primary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gunler[bugun
                            .subtract(Duration(days: deger.length - 1 - i))
                            .weekday -
                        1],
                    style: t.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Ayarlar extends StatelessWidget {
  const _Ayarlar();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ayarlar', style: t.textTheme.titleLarge),
                const SizedBox(height: 16),
                Text('Günlük kelime hedefi', style: t.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 5, label: Text('5')),
                    ButtonSegment(value: 10, label: Text('10')),
                    ButtonSegment(value: 20, label: Text('20')),
                    ButtonSegment(value: 30, label: Text('30')),
                  ],
                  selected: {s.dailyGoal},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => s.setGoal(v.first),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yavaş konuşma'),
                  subtitle: const Text('Sesli okumalar daha yavaş olur'),
                  value: s.slowSpeech,
                  onChanged: s.setSlow,
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Tts.i.speak(Content.i.words.first.ex),
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Sesi dene'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Kayıtlı ses dosyası: ${Klip.adet} · Son ses hatası: ${Tts.i.sonHata ?? 'yok'}',
                  style: t.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () async {
                    final onay = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('İlerleme silinsin mi?'),
                        content: const Text(
                          'Tüm kelime ilerlemen, serin ve puanların silinir. Geri alınamaz.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Vazgeç'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                    );
                    if (onay == true) {
                      await s.resetAll();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'İlerlemeyi sıfırla',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kelimeler: ${Content.i.words.length} · Diyalog: ${Content.i.dialogues.length} · Makale: ${Content.i.articles.length}',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

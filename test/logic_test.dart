import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:devenglish/data.dart';
import 'package:devenglish/screens/reading.dart';
import 'package:devenglish/screens/words.dart';
import 'package:devenglish/store.dart';
import 'package:devenglish/text_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('metin karşılaştırma', () {
    test('tam doğru cümle %100', () {
      final a = align(
        'The function returns true if the file exists.',
        'the function returns true if the file exists',
      );
      expect(a.percent, 100);
    });

    test('eksik sözcük kırmızı, yüzde düşer', () {
      final a = align(
        'I fixed the bug and pushed my changes.',
        'I fixed the bug and pushed changes',
      );
      expect(a.hit.where((h) => !h).length, 1);
      expect(a.targetWords[a.hit.indexOf(false)], 'my');
      expect(a.percent, 88); // 7/8 sözcük
    });

    test('kısaltmalar eşitlenir (I am / I\'m, can\'t / cannot)', () {
      expect(align("I'm learning", 'I am learning').percent, 100);
      expect(align("I can't do it", 'I cannot do it').percent, 100);
    });

    test('sıra önemli: ters cümle düşük puan', () {
      expect(
        align('open the file now', 'now file the open').percent,
        lessThan(60),
      );
    });

    test('anahtar kelime: kısaltma ve çekim ekleri', () {
      final h = keywordHits('a p i is a set of rules and I learned a lot', [
        'api',
        'rules',
        'learn',
        'server',
      ]);
      expect(h['api'], isTrue);
      expect(h['rules'], isTrue);
      expect(h['learn'], isTrue);
      expect(h['server'], isFalse);
    });

    test('yazılan cevap: büyük/küçük harf ve tek harf hatası', () {
      expect(typedMatches('Latency', 'latency'), isTrue);
      expect(typedMatches('latensy', 'latency'), isTrue);
      expect(typedMatches('cache', 'cash'), isFalse);
      expect(typedMatches('', 'cash'), isFalse);
    });
  });

  group('tekrar planı (SRS)', () {
    late Store s;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      s = Store();
      await s.load();
      s.now = () => DateTime(2026, 10, 3, 12);
    });

    test(
      'doğru cevapta kutu artar, tarih uzar; yanlışta bugün tekrar',
      () async {
        final t = s.today;
        await s.grade('api', true); // yeni + doğru -> kutu 1, yarın
        expect(s.words['api']!.box, 1);
        expect(s.words['api']!.due, t + 1);
        s.now = () => DateTime(2026, 10, 4, 12);
        await s.grade('api', true); // kutu 2, +3 gün
        expect(s.words['api']!.box, 2);
        expect(s.words['api']!.due, s.today + 3);
        await s.grade('api', false); // kutu 1'e düşer, bugün tekrar
        expect(s.words['api']!.box, 1);
        expect(s.words['api']!.due, s.today);
      },
    );

    test('yeni kelime ilk denemede yanlışsa bugün tekrar çıkar', () async {
      await s.grade('cache', false);
      expect(s.words['cache']!.box, 0);
      expect(s.words['cache']!.due, s.today);
    });

    test('seri: ardışık günler sayılır', () async {
      for (final gun in [1, 2, 3]) {
        s.now = () => DateTime(2026, 10, gun, 10);
        await s.addXp(10);
      }
      s.now = () => DateTime(2026, 10, 3, 20);
      expect(s.streak, 3);
      s.now = () => DateTime(
        2026,
        10,
        4,
        9,
      ); // bugün henüz çalışılmadı: seri dünden sayılır
      expect(s.streak, 3);
      s.now = () => DateTime(2026, 10, 6, 9); // iki gün boşluk
      expect(s.streak, 0);
    });

    test('kayıt diskten geri okunur', () async {
      await s.grade('loop', true);
      await s.addXp(25);
      final s2 = Store();
      await s2.load();
      expect(s2.words['loop']!.box, 1);
      expect(s2.totalXp, 25);
    });
  });

  group('içerik bütünlüğü', () {
    setUpAll(() async {
      await Content.load();
    });

    test('kelimeler: benzersiz, alanlar dolu, kategoriler geçerli', () {
      final c = Content.i;
      expect(c.words.length, greaterThanOrEqualTo(300));
      expect(c.words.map((w) => w.id).toSet().length, c.words.length);
      final kategoriler = c.categories.map((k) => k.id).toSet();
      for (final w in c.words) {
        expect(w.term.trim(), isNotEmpty);
        expect(w.tr.trim(), isNotEmpty, reason: w.term);
        expect(w.def.trim(), isNotEmpty, reason: w.term);
        expect(w.ex.trim(), isNotEmpty, reason: w.term);
        expect(kategoriler, contains(w.cat), reason: w.term);
      }
      // çoğu kelimeden boşluk doldurma yapılabilmeli
      expect(
        c.words.where((w) => w.hasCloze).length,
        greaterThan(c.words.length * 0.95),
      );
    });

    test('her kategoride çoğunluk yazılım alanı', () {
      final c = Content.i;
      final muhendislik = c.words.where((w) => w.cat == 'eng').length;
      expect(muhendislik / c.words.length, lessThan(0.15));
    });

    test('sorular: cevap indeksi geçerli, seçenekler benzersiz', () {
      final c = Content.i;
      final tum = [
        for (final d in c.dialogues) ...d.questions,
        for (final a in c.articles) ...a.questions,
      ];
      expect(tum, isNotEmpty);
      for (final q in tum) {
        expect(
          q.answer,
          inInclusiveRange(0, q.options.length - 1),
          reason: q.q,
        );
        expect(q.options.toSet().length, q.options.length, reason: q.q);
      }
    });

    test('dikte cümleleri tokenlenebilir ve kendisiyle %100 eşleşir', () {
      for (final s in Content.i.sentences) {
        expect(align(s.text, s.text).percent, 100, reason: s.text);
      }
    });

    test('makale sözlükçesi dokunulabilir parçalara bölünür', () {
      final a = Content.i.articles.first;
      final parcalar = parcala(
        a.paragraphs[1],
        a.glossary.keys.map((e) => e.toLowerCase()),
      );
      expect(parcalar.where((p) => p.key != null), isNotEmpty);
      expect(parcalar.map((p) => p.text).join(), a.paragraphs[1]);
    });
  });

  group('alıştırma seçimi', () {
    test('yeni kelime yalnızca çoktan seçmeli; usta kelime daha zor türler alabilir', () {
      final w = Word(
        'x',
        'cache',
        'n.',
        'önbellek',
        'd',
        'Use a cache here.',
        'dsa',
      );
      for (var i = 0; i < 40; i++) {
        expect(alistirmaTuru(w, null, Random(i)), ExType.termToTr);
      }
      final turler = {
        for (var i = 0; i < 80; i++)
          alistirmaTuru(w, WordState(4, 0, 3, 0), Random(i)),
      };
      expect(
        turler,
        containsAll([
          ExType.trToTerm,
          ExType.cloze,
          ExType.dictation,
          ExType.flash,
        ]),
      );
    });
  });
}

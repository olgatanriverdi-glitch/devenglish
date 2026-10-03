import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:devenglish/data.dart';
import 'package:devenglish/speech.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('anahtar: sabit ve ses türüne göre farklı', () {
    expect(Klip.anahtar('function', 0), Klip.anahtar('function', 0));
    expect(Klip.anahtar('function', 0), isNot(Klip.anahtar('function', 1)));
    expect(Klip.anahtar('function', 0).length, 16);
  });

  test('içerikteki her İngilizce metnin kayıtlı sesi var', () async {
    await Content.load();
    final c = Content.i;
    final eksik = <String>[];
    void kontrol(String metin, int ses) {
      if (!File('assets/audio/${Klip.anahtar(metin, ses)}.m4a').existsSync()) {
        eksik.add(metin);
      }
    }

    for (final w in c.words) {
      kontrol(w.term, 0);
      kontrol(w.ex, 0);
    }
    for (final d in c.dialogues) {
      for (final l in d.lines) {
        kontrol(l.text, l.speaker);
      }
    }
    for (final s in c.sentences) {
      kontrol(s.text, 0);
    }
    for (final p in c.prompts) {
      kontrol(p.question, 0);
      kontrol(p.model, 0);
    }
    for (final w in c.pron) {
      kontrol(w.word, 0);
    }
    for (final a in c.articles) {
      for (final p in a.paragraphs) {
        kontrol(p, 0);
      }
    }
    expect(
      eksik,
      isEmpty,
      reason:
          'Ses yok (python3 tools/make_audio.py çalıştır): ${eksik.take(5)}',
    );
  });

  test('ses dosyaları boş değil', () {
    final dosyalar = Directory('assets/audio')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.m4a'));
    expect(dosyalar.length, greaterThan(2000));
    for (final f in dosyalar) {
      expect(f.lengthSync(), greaterThan(2000), reason: f.path);
    }
  });
}

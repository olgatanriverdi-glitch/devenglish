// Web: tarayıcının konuşma motorunu doğrudan kullanır ve İngilizce sesi zorlar.
// (flutter_tts web'de ses listesi geç yüklenince dili hiç uygulamıyor; telefon Türkçe sesle okuyordu.)
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const _tercih = [
  'Samantha',
  'Daniel',
  'Alex',
  'Karen',
  'Google US English',
  'Google UK English',
  'Microsoft Aria',
  'Microsoft Guy',
  'Microsoft Jenny',
  'Microsoft Zira',
  'Microsoft David',
];

bool _ingilizce(web.SpeechSynthesisVoice v) {
  final l = v.lang.replaceAll('_', '-').toLowerCase();
  return l.startsWith('en-us') || l.startsWith('en-gb') || l == 'en';
}

/// Ses listesi Safari/Chrome'da geç dolar; en çok ~2 sn bekle.
Future<List<web.SpeechSynthesisVoice>> _sesler() async {
  for (var i = 0; i < 20; i++) {
    final l = web.window.speechSynthesis.getVoices().toDart;
    if (l.isNotEmpty) return l;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return [];
}

web.SpeechSynthesisVoice? _sec(
  List<web.SpeechSynthesisVoice> hepsi,
  int konusmaci,
) {
  final en = hepsi.where(_ingilizce).toList();
  if (en.isEmpty) return null;
  int puan(web.SpeechSynthesisVoice v) {
    final i = _tercih.indexWhere((t) => v.name.contains(t));
    final us = v.lang.replaceAll('_', '-').toLowerCase().startsWith('en-us')
        ? 0
        : 1;
    return (i < 0 ? 50 : i) * 2 + us;
  }

  en.sort((a, b) => puan(a).compareTo(puan(b)));
  return en[konusmaci < en.length ? konusmaci : 0];
}

Future<void> sesDurdur() async => web.window.speechSynthesis.cancel();

/// Metni İngilizce okur; bitince (ya da hata/zaman aşımında) döner.
Future<void> konus(
  String metin, {
  required int konusmaci,
  required bool yavas,
}) async {
  final synth = web.window.speechSynthesis;
  final sesler = await _sesler();
  synth.cancel();
  final u = web.SpeechSynthesisUtterance(metin);
  u.lang = 'en-US';
  u.rate = yavas ? 0.7 : 0.95;
  u.pitch = 1.0;
  final ses = _sec(sesler, konusmaci);
  if (ses != null) {
    u.voice = ses;
    u.lang = ses.lang;
  }
  final bitti = Completer<void>();
  u.onend = ((web.Event _) {
    if (!bitti.isCompleted) bitti.complete();
  }).toJS;
  u.onerror = ((web.Event _) {
    if (!bitti.isCompleted) bitti.complete();
  }).toJS;
  synth.speak(u);
  await bitti.future;
}

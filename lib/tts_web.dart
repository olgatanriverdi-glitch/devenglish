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
  if (ses == null) {
    // İngilizce ses yoksa cihaz Türkçe sesle İngilizceyi heceleyerek okur; bunu hiç yapma.
    throw StateError('Bu cihazda İngilizce ses yok');
  }
  u.voice = ses;
  u.lang = ses.lang;
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

// ---- Önceden kaydedilmiş sesler ----
// iPhone Safari, sesin ancak dokunma (kullanıcı hareketi) anında başlatılmasına izin verir.
// Bu yüzden tek bir Audio öğesi kullanılır ve play() çağrısı hiçbir await'ten önce yapılır;
// öğe bir kez "açıldıktan" sonra arka arkaya çalınan kayıtlar (diyalog) da engellenmez.
web.HTMLAudioElement? _audio;
Completer<void>? _calan;

/// [url]: sayfaya göre göreli adres (örn. assets/assets/audio/xxxx.m4a). Bitince döner; çalma reddedilirse hata fırlatır.
Future<void> klipCal(String url, {required bool yavas, required int sureSn}) {
  final a = _audio ??= web.HTMLAudioElement();
  final onceki = _calan;
  if (onceki != null && !onceki.isCompleted) {
    onceki.complete();
  }
  final bitti = Completer<void>();
  _calan = bitti;
  a.onended = ((web.Event _) {
    if (!bitti.isCompleted) bitti.complete();
  }).toJS;
  a.onerror = ((web.Event _) {
    if (!bitti.isCompleted) {
      bitti.completeError('ses dosyası yüklenemedi: $url');
    }
  }).toJS;
  a.src = url;
  a.playbackRate = yavas ? 0.75 : 1.0;
  final vaat = a.play(); // senkron: kullanıcı hareketi bitmeden çağrılır
  return () async {
    await vaat.toDart; // NotAllowedError vb. burada hata olarak görünür
    await bitti.future.timeout(Duration(seconds: sureSn), onTimeout: () {});
  }();
}

void klipDurdur() {
  final b = _calan;
  if (b != null && !b.isCompleted) {
    b.complete();
  }
  _audio?.pause();
}

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show GlobalKey, ScaffoldMessengerState, SnackBar, Text;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'store.dart';
import 'tts_web_stub.dart'
    if (dart.library.js_interop) 'tts_web.dart'
    as webtts;

/// Önceden kaydedilmiş ses dosyaları (assets/audio, tools/make_audio.py ile üretilir).
/// Cihazın kendi sesi (özellikle Türkçe telefonlarda) İngilizceyi yanlış okuyabildiği için önce bunlar çalınır.
/// Ses 0 = Samantha (ABD, kadın), ses 1 = Daniel (İngiltere, erkek).
class Klip {
  static Set<String> _var = {};
  static AudioPlayer? _oynatici;
  static Completer<void>? _bekleyen;

  static Future<void> yukle() async {
    try {
      final m = await AssetManifest.loadFromAssetBundle(rootBundle);
      _var = m.listAssets().where((a) => a.startsWith('assets/audio/')).toSet();
    } catch (e) {
      debugPrint('Ses dosyaları listelenemedi: $e');
    }
  }

  static int get adet => _var.length;

  /// Dosya adı anahtarı: ses a/b (normal), as/bs (yavaş kayıt). tools/make_audio.py ile aynı biçim.
  static String anahtar(String metin, int konusmaci, {bool yavas = false}) {
    final ses = (konusmaci == 1 ? 'b' : 'a') + (yavas ? 's' : '');
    return sha1.convert(utf8.encode('$ses|$metin')).toString().substring(0, 16);
  }

  static String? _varsa(String metin, int konusmaci, bool yavas) {
    final k = anahtar(metin, konusmaci, yavas: yavas);
    return _var.contains('assets/audio/$k.m4a') ? 'audio/$k.m4a' : null;
  }

  /// Metin için kayıt: yavaş isteniyorsa önce ayrı yavaş kayıt aranır (çalarken yavaşlatmak sesi titretir).
  /// [yavaslat] true ise yavaş kayıt yoktur ve çalarken yavaşlatılmalıdır.
  static ({String yol, bool yavaslat})? bul(
    String metin,
    int konusmaci,
    bool yavas,
  ) {
    if (yavas) {
      final y = _varsa(metin, konusmaci, true);
      if (y != null) return (yol: y, yavaslat: false);
    }
    final n = _varsa(metin, konusmaci, false);
    return n == null ? null : (yol: n, yavaslat: yavas);
  }

  /// Kaydı çalar; bitince döner. Durdurulursa ya da zaman aşımında da döner.
  static Future<void> cal(
    String yol, {
    required bool yavas,
    required int karakter,
  }) {
    if (kIsWeb) {
      // await'ten önce, doğrudan dokunma anında başlat (iPhone Safari kuralı)
      return webtts.klipCal(
        'assets/assets/$yol',
        yavas: yavas,
        sureSn: 8 + karakter ~/ 4,
      );
    }
    return _calYerel(yol, yavas: yavas, karakter: karakter);
  }

  static Future<void> _calYerel(
    String yol, {
    required bool yavas,
    required int karakter,
  }) async {
    final p = _oynatici ??= AudioPlayer();
    await durdur();
    final bitti = Completer<void>();
    _bekleyen = bitti;
    final abone = p.onPlayerComplete.listen((_) {
      if (!bitti.isCompleted) bitti.complete();
    });
    try {
      if (!kIsWeb && Platform.isIOS) {
        await p.setAudioContext(
          AudioContext(
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        );
      }
      await p.setPlaybackRate(yavas ? 0.75 : 1.0);
      await p.play(AssetSource(yol));
      await bitti.future.timeout(
        Duration(seconds: 8 + karakter ~/ 4),
        onTimeout: () {},
      );
    } finally {
      await abone.cancel();
      if (identical(_bekleyen, bitti)) _bekleyen = null;
    }
  }

  static Future<void> durdur() async {
    if (kIsWeb) webtts.klipDurdur();
    final b = _bekleyen;
    if (b != null && !b.isCompleted) b.complete();
    _bekleyen = null;
    try {
      await _oynatici?.stop();
    } catch (_) {}
  }
}

/// Metin okuma (dinleme çalışmaları ve model telaffuz). Platform yoksa sessizce hiçbir şey yapmaz.
class Tts {
  static final Tts i = Tts._();
  static final GlobalKey<ScaffoldMessengerState> mesajci =
      GlobalKey<ScaffoldMessengerState>();
  String? sonHata;

  void _hataBildir(String m) {
    sonHata = m;
    debugPrint(m);
    mesajci.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Tts._();

  final FlutterTts _t = FlutterTts();
  bool _hazir = false;
  bool _calisiyor = false;
  int _belirtec =
      0; // her speak/stop ile artar; eski oynatma döngülerini iptal eder
  final List<Map<String, String>> _sesler = [];
  final ValueNotifier<bool> konusuyor = ValueNotifier(false);

  Future<void> init() async {
    if (_hazir) return;
    try {
      await _t.setLanguage('en-US');
      await _t.awaitSpeakCompletion(true);
      await _t.setVolume(1.0);
      if (!kIsWeb && Platform.isIOS) {
        // Sessiz modda da konuşsun, hoparlörden çıksın, mikrofonla (konuşma tanıma) birlikte çalışsın
        await _t.setSharedInstance(true);
        await _t.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playAndRecord,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }
      await _sesleriSec();
      _hazir = true;
    } catch (e) {
      debugPrint('TTS başlatılamadı: $e');
    }
  }

  Future<void> _sesleriSec() async {
    try {
      final v = await _t.getVoices;
      if (v is! List) return;
      final en = <Map<String, String>>[];
      for (final x in v) {
        if (x is! Map) continue;
        final loc = '${x['locale']}'.replaceAll('_', '-');
        if (loc.startsWith('en-US') || loc.startsWith('en-GB')) {
          en.add({'name': '${x['name']}', 'locale': '${x['locale']}'});
        }
      }
      // Tercih edilen, doğal sesli isimler önce
      const tercih = [
        'Samantha',
        'Daniel',
        'Alex',
        'Karen',
        'Google US English',
        'Google UK English Male',
      ];
      en.sort((a, b) {
        int p(Map<String, String> m) {
          final i = tercih.indexWhere((t) => m['name']!.contains(t));
          return i < 0 ? 99 : i;
        }

        return p(a).compareTo(p(b));
      });
      _sesler
        ..clear()
        ..addAll(en.take(2));
    } catch (_) {}
  }

  double _hiz(bool yavas) =>
      kIsWeb ? (yavas ? 0.7 : 1.0) : (yavas ? 0.34 : 0.5);

  /// Metni okur ve bitince döner. [konusmaci] 0 ya da 1: farklı ses/ton.
  Future<void> speak(String text, {int konusmaci = 0, bool? yavas}) async {
    final slow = yavas ?? Store.i.slowSpeech;
    final kayit = Klip.bul(text, konusmaci, slow);
    if (kayit != null) {
      final benim = ++_belirtec;
      konusuyor.value = true;
      try {
        await Klip.cal(kayit.yol, yavas: kayit.yavaslat, karakter: text.length);
        return;
      } catch (e) {
        _hataBildir('Ses çalınamadı: $e');
        // Web'de cihaz sesine dönmek İngilizceyi Türkçe okutabilir; hata gösterip dur.
        if (kIsWeb) return;
      } finally {
        if (benim == _belirtec) konusuyor.value = false;
      }
    }
    if (kIsWeb) return _webKonus(text, konusmaci, yavas ?? Store.i.slowSpeech);
    await init();
    if (!_hazir) return;
    final benim = ++_belirtec;
    try {
      if (_calisiyor) await _t.stop();
      final slow = yavas ?? Store.i.slowSpeech;
      await _t.setSpeechRate(_hiz(slow));
      if (_sesler.length > konusmaci) {
        await _t.setVoice(_sesler[konusmaci]);
        await _t.setPitch(1.0);
      } else {
        await _t.setPitch(konusmaci == 0 ? 1.0 : 1.25);
      }
      if (benim != _belirtec) return;
      _calisiyor = true;
      konusuyor.value = true;
      // Bazı cihazlarda "bitti" sinyali hiç gelmeyebilir; metin uzunluğuna göre makul bir üst süre koy.
      await _t
          .speak(text)
          .timeout(
            Duration(seconds: 6 + text.length ~/ 6),
            onTimeout: () => null,
          );
    } catch (e) {
      debugPrint('TTS hata: $e');
    } finally {
      if (benim == _belirtec) {
        _calisiyor = false;
        konusuyor.value = false;
      }
    }
  }

  Future<void> _webKonus(String text, int konusmaci, bool yavas) async {
    final benim = ++_belirtec;
    konusuyor.value = true;
    try {
      await webtts
          .konus(text, konusmaci: konusmaci, yavas: yavas)
          .timeout(Duration(seconds: 6 + text.length ~/ 5), onTimeout: () {});
    } catch (e) {
      _hataBildir('Ses çalınamadı: $e');
    } finally {
      if (benim == _belirtec) konusuyor.value = false;
    }
  }

  /// Bir [speak] çağrısı sonrası hâlâ aynı oynatma sırasındaysak true (diyalog döngüsü için).
  int get belirtec => _belirtec;

  Future<void> stop() async {
    _belirtec++;
    await Klip.durdur();
    if (kIsWeb) {
      await webtts.sesDurdur();
      konusuyor.value = false;
      return;
    }
    try {
      await _t.stop();
    } catch (_) {}
    _calisiyor = false;
    konusuyor.value = false;
  }
}

/// Konuşma tanıma. Web'de yalnızca Chrome/Safari gibi desteklenen tarayıcılarda, iPhone'da izin verilirse çalışır.
class Stt {
  static final Stt i = Stt._();
  Stt._();

  final SpeechToText _s = SpeechToText();
  Future<bool>? _basliyor;
  bool available = false;
  String? sonHata;
  final ValueNotifier<bool> dinliyor = ValueNotifier(false);

  /// Konuşma tanımayı hazırlar. İzin penceresi cevapsız kalırsa 12 sn sonra vazgeçer; sonraki basışta yeniden dener.
  Future<bool> init() async {
    if (available) return true;
    return _basliyor ??= _hazirla().whenComplete(() => _basliyor = null);
  }

  Future<bool> _hazirla() async {
    try {
      available = await _s
          .initialize(
            onError: (e) {
              sonHata = e.errorMsg;
              dinliyor.value = false;
            },
            onStatus: (s) {
              if (s == 'done' || s == 'notListening') dinliyor.value = false;
            },
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              sonHata = 'Mikrofon izni verilmedi ya da tarayıcı desteklemiyor';
              return false;
            },
          );
    } catch (e) {
      sonHata = '$e';
      available = false;
    }
    return available;
  }

  Future<bool> start({
    required void Function(String text, bool finalResult) onResult,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!await init()) return false;
    await Tts.i.stop();
    sonHata = null;
    try {
      await _s.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: listenFor,
          pauseFor: pauseFor,
          localeId: 'en_US',
        ),
      );
      dinliyor.value = true;
      return true;
    } catch (e) {
      sonHata = '$e';
      dinliyor.value = false;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _s.stop();
    } catch (_) {}
    dinliyor.value = false;
  }

  Future<void> cancel() async {
    try {
      await _s.cancel();
    } catch (_) {}
    dinliyor.value = false;
  }
}

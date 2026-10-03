import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'store.dart';

/// Metin okuma (dinleme çalışmaları ve model telaffuz). Platform yoksa sessizce hiçbir şey yapmaz.
class Tts {
  static final Tts i = Tts._();
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
      await _t.speak(text);
    } catch (e) {
      debugPrint('TTS hata: $e');
    } finally {
      if (benim == _belirtec) {
        _calisiyor = false;
        konusuyor.value = false;
      }
    }
  }

  /// Bir [speak] çağrısı sonrası hâlâ aynı oynatma sırasındaysak true (diyalog döngüsü için).
  int get belirtec => _belirtec;

  Future<void> stop() async {
    _belirtec++;
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

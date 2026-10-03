import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

/// Tekrar aralığı (gün), kutu numarasına göre. Kutu 0 = yeni öğrenilmiş.
const List<int> kAralik = [0, 1, 3, 7, 16, 35];

class WordState {
  int box; // 0..5
  int due; // gün numarası (epoch day)
  int right, wrong;
  WordState(this.box, this.due, this.right, this.wrong);
  Map<String, dynamic> toJson() => {'b': box, 'd': due, 'r': right, 'w': wrong};
  factory WordState.fromJson(Map<String, dynamic> j) =>
      WordState(j['b'], j['d'], j['r'] ?? 0, j['w'] ?? 0);
}

class DayStats {
  int words = 0, listening = 0, speaking = 0, reading = 0, xp = 0;
  Map<String, dynamic> toJson() => {
    'w': words,
    'l': listening,
    's': speaking,
    'r': reading,
    'x': xp,
  };
  DayStats();
  factory DayStats.fromJson(Map<String, dynamic> j) {
    final d = DayStats();
    d.words = j['w'] ?? 0;
    d.listening = j['l'] ?? 0;
    d.speaking = j['s'] ?? 0;
    d.reading = j['r'] ?? 0;
    d.xp = j['x'] ?? 0;
    return d;
  }
}

int epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// İlerleme, ayarlar ve tekrar planı. Tek bir JSON olarak SharedPreferences'ta saklanır.
class Store extends ChangeNotifier {
  static final Store i = Store();
  static const _anahtar = 'devenglish.v1';

  final Map<String, WordState> words = {};
  final Map<String, DayStats> days = {};
  final Set<String> readArticles = {};
  final Map<String, int> best = {}; // 'dlg:id' / 'art:id' -> en iyi yüzde
  int dailyGoal = 10;
  bool slowSpeech = false;

  DateTime Function() now = DateTime.now; // testlerde değiştirilebilir
  SharedPreferences? _p;

  int get today => epochDay(now());

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final s = _p!.getString(_anahtar);
    if (s == null) return;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      (j['words'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => words[k] = WordState.fromJson(v as Map<String, dynamic>),
      );
      (j['days'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => days[k] = DayStats.fromJson(v as Map<String, dynamic>),
      );
      readArticles.addAll(((j['read'] ?? []) as List).cast<String>());
      (j['best'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => best[k] = v as int,
      );
      dailyGoal = j['goal'] ?? 10;
      slowSpeech = j['slow'] ?? false;
    } catch (_) {
      // bozuk kayıt: temiz başla
    }
  }

  Future<void> _save() async {
    notifyListeners();
    final p = _p;
    if (p == null) return;
    await p.setString(
      _anahtar,
      jsonEncode({
        'words': words.map((k, v) => MapEntry(k, v.toJson())),
        'days': days.map((k, v) => MapEntry(k, v.toJson())),
        'read': readArticles.toList(),
        'best': best,
        'goal': dailyGoal,
        'slow': slowSpeech,
      }),
    );
  }

  // ---- günlük istatistik ----
  DayStats get todayStats => days[dayKey(now())] ?? DayStats();

  DayStats _bugunYaz() => days.putIfAbsent(dayKey(now()), () => DayStats());

  Future<void> addXp(int n) async {
    _bugunYaz().xp += n;
    await _save();
  }

  Future<void> markListening() async {
    _bugunYaz().listening++;
    await _save();
  }

  Future<void> markSpeaking() async {
    _bugunYaz().speaking++;
    await _save();
  }

  Future<void> markReading(String articleId) async {
    _bugunYaz().reading++;
    readArticles.add(articleId);
    await _save();
  }

  Future<void> saveBest(String key, int percent) async {
    if (percent > (best[key] ?? -1)) best[key] = percent;
    await _save();
  }

  /// Üst üste çalışılan gün sayısı (bugün henüz çalışılmadıysa dünden sayar).
  int get streak {
    var d = now();
    var n = 0;
    if ((days[dayKey(d)]?.xp ?? 0) == 0) {
      d = d.subtract(const Duration(days: 1));
    }
    while ((days[dayKey(d)]?.xp ?? 0) > 0) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  int get totalXp => days.values.fold(0, (a, b) => a + b.xp);

  /// Son [n] günün XP'si (eskiden yeniye).
  List<int> lastDaysXp(int n) {
    final t = now();
    return [
      for (var i = n - 1; i >= 0; i--)
        days[dayKey(t.subtract(Duration(days: i)))]?.xp ?? 0,
    ];
  }

  // ---- kelime tekrarı ----
  int get learnedCount => words.length;
  int get masteredCount => words.values.where((w) => w.box >= 4).length;
  int get learningCount => words.length - masteredCount;

  List<Word> dueWords(Content c) {
    final t = today;
    final l = c.words
        .where((w) => words[w.id] != null && words[w.id]!.due <= t)
        .toList();
    l.sort((a, b) {
      final x = words[a.id]!, y = words[b.id]!;
      final k = x.due.compareTo(y.due);
      return k != 0 ? k : x.box.compareTo(y.box);
    });
    return l;
  }

  /// Henüz görülmemiş kelimeler. [cat] verilirse o kategoriden; yoksa kategoriler arası dönüşümlü.
  List<Word> newWords(Content c, int count, {String? cat}) {
    final unseen = c.words.where((w) => !words.containsKey(w.id));
    if (cat != null) {
      return unseen.where((w) => w.cat == cat).take(count).toList();
    }
    final gruplar = <String, List<Word>>{};
    for (final w in unseen) {
      gruplar.putIfAbsent(w.cat, () => []).add(w);
    }
    final sonuc = <Word>[];
    var i = 0;
    while (sonuc.length < count && gruplar.values.any((g) => i < g.length)) {
      for (final g in gruplar.values) {
        if (i < g.length && sonuc.length < count) sonuc.add(g[i]);
      }
      i++;
    }
    return sonuc;
  }

  int newRemaining(Content c) => c.words.length - words.length;

  /// Bir kelimenin ilk deneme sonucunu kaydeder ve bir sonraki tekrar gününü belirler.
  Future<void> grade(String id, bool correct) async {
    final s = words[id];
    final t = today;
    if (s == null) {
      // yeni kelime: doğruysa 1. kutu, yanlışsa 0 (bugün tekrar)
      words[id] = correct
          ? WordState(1, t + kAralik[1], 1, 0)
          : WordState(0, t, 0, 1);
    } else if (correct) {
      s.right++;
      s.box = (s.box + 1).clamp(0, 5);
      s.due = t + kAralik[s.box];
    } else {
      s.wrong++;
      s.box = (s.box - 1).clamp(0, 5);
      s.due = t;
    }
    _bugunYaz().words++;
    await _save();
  }

  /// "Bu kelimeyi zaten biliyorum": doğrudan 3. kutuya alır.
  Future<void> markKnown(String id) async {
    words[id] = WordState(3, today + kAralik[3], 1, 0);
    await _save();
  }

  Future<void> setGoal(int n) async {
    dailyGoal = n;
    await _save();
  }

  Future<void> setSlow(bool v) async {
    slowSpeech = v;
    await _save();
  }

  Future<void> resetAll() async {
    words.clear();
    days.clear();
    readArticles.clear();
    best.clear();
    await _save();
  }
}

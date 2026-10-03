import 'dart:math';

/// Karşılaştırma için metni sadeleştirir: küçük harf, kısaltmaları aç, noktalamayı at.
String normalizeText(String s) {
  var t = s.toLowerCase().replaceAll('’', "'").replaceAll('‘', "'");
  const ozel = {
    "can't": 'can not',
    'cannot': 'can not',
    "won't": 'will not',
    "let's": 'let us',
  };
  ozel.forEach((k, v) => t = t.replaceAll(k, v));
  t = t
      .replaceAll("n't", ' not')
      .replaceAll("'m", ' am')
      .replaceAll("'re", ' are')
      .replaceAll("'ve", ' have')
      .replaceAll("'ll", ' will')
      .replaceAll("'d", ' would')
      .replaceAll("it's", 'it is')
      .replaceAll("that's", 'that is')
      .replaceAll("what's", 'what is')
      .replaceAll("there's", 'there is')
      .replaceAll("'s", '');
  return t;
}

List<String> tokenize(String s) =>
    RegExp(r"[a-z0-9]+")
        .allMatches(normalizeText(s))
        .map((m) => m.group(0)!)
        .toList();

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var onceki = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final su = List<int>.filled(b.length + 1, 0);
    su[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final m = a[i - 1] == b[j - 1] ? 0 : 1;
      su[j] = min(min(su[j - 1] + 1, onceki[j] + 1), onceki[j - 1] + m);
    }
    onceki = su;
  }
  return onceki[b.length];
}

/// İki sözcük aynı mı? Uzun sözcüklerde 1 harf farkı (çoğul, tanıma hatası) hoş görülür.
bool similarWord(String a, String b) =>
    a == b || (a.length >= 6 && b.length >= 6 && levenshtein(a, b) <= 1);

class WordAlignment {
  final List<String> targetWords;
  final List<bool> hit;
  final int extra; // söylenen ama hedefte olmayan sözcük sayısı
  WordAlignment(this.targetWords, this.hit, this.extra);

  int get hits => hit.where((h) => h).length;
  double get accuracy => targetWords.isEmpty ? 0 : hits / targetWords.length;
  int get percent => (accuracy * 100).round();
}

/// Hedef cümleyi söylenen / yazılan metinle sözcük sözcük eşler (en uzun ortak dizi).
WordAlignment align(String target, String spoken) {
  final t = tokenize(target);
  final s = tokenize(spoken);
  final dp = List.generate(
    t.length + 1,
    (_) => List<int>.filled(s.length + 1, 0),
  );
  for (var i = 1; i <= t.length; i++) {
    for (var j = 1; j <= s.length; j++) {
      dp[i][j] = similarWord(t[i - 1], s[j - 1])
          ? dp[i - 1][j - 1] + 1
          : max(dp[i - 1][j], dp[i][j - 1]);
    }
  }
  final hit = List<bool>.filled(t.length, false);
  var i = t.length, j = s.length;
  while (i > 0 && j > 0) {
    if (similarWord(t[i - 1], s[j - 1]) && dp[i][j] == dp[i - 1][j - 1] + 1) {
      hit[i - 1] = true;
      i--;
      j--;
    } else if (dp[i - 1][j] >= dp[i][j - 1]) {
      i--;
    } else {
      j--;
    }
  }
  final hits = hit.where((h) => h).length;
  return WordAlignment(t, hit, max(0, s.length - hits));
}

/// Serbest konuşmada anahtar kelimelerin hangileri geçti? (kısa kısaltmalar harf harf okunabilir: "a p i")
Map<String, bool> keywordHits(String spoken, List<String> keywords) {
  final tokens = tokenize(spoken);
  final birlesik = tokens.join('');
  return {
    for (final k in keywords)
      k:
          tokens.any(
            (w) =>
                w == k ||
                (k.length >= 4 &&
                    w.length >= 4 &&
                    w.startsWith(k.substring(0, min(k.length, 5)))),
          ) ||
          (k.length <= 3 && birlesik.contains(k)),
  };
}

/// Yazılan cevap doğru kelimeyle eşleşiyor mu? (büyük/küçük harf ve 1 harflik yazım hatası hoş görülür)
bool typedMatches(String typed, String answer) {
  final a = typed.trim().toLowerCase();
  final b = answer.trim().toLowerCase();
  if (a.isEmpty) return false;
  if (a == b) return true;
  return b.length >= 7 && levenshtein(a, b) <= 1;
}

/// Listeyi karıştırıp [n] eleman döndürür (orijinali değiştirmez).
List<T> pick<T>(List<T> l, int n, Random r) {
  final c = List<T>.of(l)..shuffle(r);
  return c.take(n).toList();
}

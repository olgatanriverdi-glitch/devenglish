import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class Word {
  final String id, term, pos, tr, def, ex, cat;
  Word(this.id, this.term, this.pos, this.tr, this.def, this.ex, this.cat);
  factory Word.fromJson(Map<String, dynamic> j) =>
      Word(j['id'], j['term'], j['pos'], j['tr'], j['def'], j['ex'], j['cat']);

  /// Örnek cümlede terim aynen geçiyorsa boşluk doldurma sorusu yapılabilir.
  bool get hasCloze => ex.toLowerCase().contains(term.toLowerCase());

  /// Örnek cümlede terimin yerine boşluk koyar.
  String get clozeText {
    final i = ex.toLowerCase().indexOf(term.toLowerCase());
    if (i < 0) return ex;
    return '${ex.substring(0, i)}_____${ex.substring(i + term.length)}';
  }
}

class Category {
  final String id, name;
  Category(this.id, this.name);
}

class Quiz {
  final String q, why;
  final List<String> options;
  final int answer;
  Quiz(this.q, this.options, this.answer, this.why);
  factory Quiz.fromJson(Map<String, dynamic> j) => Quiz(
    j['q'],
    (j['options'] as List).cast<String>(),
    j['answer'] as int,
    (j['why'] ?? '') as String,
  );
}

class DialogueLine {
  final int speaker;
  final String text;
  DialogueLine(this.speaker, this.text);
}

class Dialogue {
  final String id, title, level, about;
  final int minutes;
  final List<DialogueLine> lines;
  final List<Quiz> questions;
  Dialogue(
    this.id,
    this.title,
    this.level,
    this.about,
    this.minutes,
    this.lines,
    this.questions,
  );
  factory Dialogue.fromJson(Map<String, dynamic> j) => Dialogue(
    j['id'],
    j['title'],
    j['level'],
    j['about'],
    j['minutes'] as int,
    (j['lines'] as List)
        .map((l) => DialogueLine(l['s'] as int, l['t'] as String))
        .toList(),
    (j['questions'] as List)
        .map((q) => Quiz.fromJson(q as Map<String, dynamic>))
        .toList(),
  );
  bool get singleSpeaker => lines.every((l) => l.speaker == 0);
}

class Sentence {
  final String text, level, tr;
  Sentence(this.text, this.level, this.tr);
}

class SpeakPrompt {
  final String id, level, question, model, tip;
  final List<String> keywords;
  SpeakPrompt(
    this.id,
    this.level,
    this.question,
    this.model,
    this.tip,
    this.keywords,
  );
}

class PronWord {
  final String word, ipa, tip;
  PronWord(this.word, this.ipa, this.tip);
}

class Article {
  final String id, title, level, summary;
  final int minutes, words;
  final List<String> paragraphs;
  final Map<String, String> glossary;
  final List<Quiz> questions;
  Article(
    this.id,
    this.title,
    this.level,
    this.summary,
    this.minutes,
    this.words,
    this.paragraphs,
    this.glossary,
    this.questions,
  );
  factory Article.fromJson(Map<String, dynamic> j) => Article(
    j['id'],
    j['title'],
    j['level'],
    j['summary'],
    j['minutes'] as int,
    j['words'] as int,
    (j['paragraphs'] as List).cast<String>(),
    (j['glossary'] as Map).map((k, v) => MapEntry(k as String, v as String)),
    (j['questions'] as List)
        .map((q) => Quiz.fromJson(q as Map<String, dynamic>))
        .toList(),
  );
}

class LinkItem {
  final String title, url, level, note;
  LinkItem(this.title, this.url, this.level, this.note);
}

/// Uygulamayla gelen içerik (assets/data/*.json). Bir kez yüklenir.
class Content {
  static late Content i;

  final List<Category> categories;
  final List<Word> words;
  final List<Dialogue> dialogues;
  final List<Sentence> sentences;
  final List<SpeakPrompt> prompts;
  final List<PronWord> pron;
  final List<Article> articles;
  final List<LinkItem> links;
  final Map<String, Word> _byId;

  Content(
    this.categories,
    this.words,
    this.dialogues,
    this.sentences,
    this.prompts,
    this.pron,
    this.articles,
    this.links,
  ) : _byId = {for (final w in words) w.id: w};

  Word? wordById(String id) => _byId[id];

  /// Küçük harfli terim -> kelime (makale içi dokunma sözlüğü için).
  late final Map<String, Word> byTerm = {
    for (final w in words) w.term.toLowerCase(): w,
  };

  String categoryName(String id) => categories
      .firstWhere((c) => c.id == id, orElse: () => Category(id, id))
      .name;

  static Future<Map<String, dynamic>> _json(String ad) async =>
      jsonDecode(await rootBundle.loadString('assets/data/$ad'))
          as Map<String, dynamic>;

  static Future<void> load() async {
    final v = await _json('vocab.json');
    final l = await _json('listening.json');
    final s = await _json('speaking.json');
    final a = await _json('articles.json');
    i = Content(
      (v['categories'] as List)
          .map((c) => Category(c['id'], c['name']))
          .toList(),
      (v['words'] as List)
          .map((w) => Word.fromJson(w as Map<String, dynamic>))
          .toList(),
      (l['dialogues'] as List)
          .map((d) => Dialogue.fromJson(d as Map<String, dynamic>))
          .toList(),
      (l['sentences'] as List)
          .map((x) => Sentence(x['t'], x['level'], x['tr']))
          .toList(),
      (s['prompts'] as List)
          .map(
            (p) => SpeakPrompt(
              p['id'],
              p['level'],
              p['q'],
              p['model'],
              p['tip'],
              (p['keywords'] as List).cast<String>(),
            ),
          )
          .toList(),
      (s['words'] as List)
          .map((w) => PronWord(w['w'], w['ipa'], w['tip']))
          .toList(),
      (a['articles'] as List)
          .map((x) => Article.fromJson(x as Map<String, dynamic>))
          .toList(),
      (a['links'] as List)
          .map((x) => LinkItem(x['title'], x['url'], x['level'], x['note']))
          .toList(),
    );
  }
}

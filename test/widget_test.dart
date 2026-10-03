import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:devenglish/data.dart';
import 'package:devenglish/main.dart';
import 'package:devenglish/screens/words.dart';
import 'package:devenglish/widgets.dart';
import 'package:devenglish/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Store.i.words.clear();
    Store.i.days.clear();
    await Content.load();
  });

  testWidgets('beş sekme açılır ve içerik görünür', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(
      1000,
      2000,
    ); // Ahem yazı tipi geniş olduğu için geniş ekran
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DevEnglishApp());
    await tester.pumpAndSettle();
    expect(find.text('DevEnglish'), findsOneWidget);
    expect(find.text('Günlük çalışmaya başla'), findsOneWidget);

    await tester.tap(find.text('Kelime').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('kelimelik yazılım sözlüğü'), findsOneWidget);

    await tester.tap(find.text('Dinle').last);
    await tester.pumpAndSettle();
    expect(find.text('Dikte'), findsOneWidget);
    expect(find.text('Daily Stand-up'), findsOneWidget);

    await tester.tap(find.text('Konuş').last);
    await tester.pumpAndSettle();
    expect(find.text('Cümle oku'), findsOneWidget);

    await tester.tap(find.text('Oku').last);
    await tester.pumpAndSettle();
    expect(find.text('What Happens When You Type a URL?'), findsOneWidget);
  });

  testWidgets('kelime oturumu: tanıtım, soru, yanlış cevap ve tekrar kuyruğu', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(
      1000,
      2000,
    ); // Ahem yazı tipi geniş olduğu için geniş ekran
    addTearDown(tester.view.reset);
    final yeni = Content.i.words.take(3).toList();
    await tester.pumpWidget(
      MaterialApp(
        home: WordSession(review: const [], fresh: yeni),
      ),
    );
    await tester.pumpAndSettle();

    // 3 tanıtım kartı
    for (var i = 0; i < 3; i++) {
      expect(find.text('Yeni kelime'), findsOneWidget);
      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();
    }
    // ilk soru: Türkçesi?
    expect(find.text('Bu kelimenin Türkçesi nedir?'), findsOneWidget);
    expect(find.text('4 / 6'), findsOneWidget); // 3 tanıtımdan sonra 4. adım
    final dogru = yeni.first.tr;
    // yanlış bir şık bul ve dokun
    final secenekler = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ChoiceList),
            matching: find.byType(Text),
          ),
        )
        .toList();
    expect(secenekler.length, 4);
    final yanlis = secenekler.firstWhere((t) => t.data != dogru).data!;
    await tester.tap(find.text(yanlis));
    await tester.pumpAndSettle();
    expect(find.textContaining('Doğrusu: $dogru'), findsOneWidget);
    expect(Store.i.words[yeni.first.id]!.box, 0); // yanlış: bugün tekrar
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    // kuyruk uzadı: 6 + 1 tekrar
    expect(find.text('5 / 7'), findsOneWidget);
  });
}

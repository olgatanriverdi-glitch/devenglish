import 'package:flutter/material.dart';

import 'data.dart';
import 'screens/home.dart';
import 'screens/listening.dart';
import 'screens/reading.dart';
import 'screens/speaking.dart';
import 'screens/words.dart';
import 'speech.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.i.load();
  await Content.load();
  await Klip.yukle();
  runApp(const DevEnglishApp());
}

class DevEnglishApp extends StatelessWidget {
  const DevEnglishApp({super.key});

  @override
  Widget build(BuildContext context) {
    const tohum = Color(0xFF3D6DF2);
    ThemeData tema(Brightness b) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: tohum, brightness: b),
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
    return MaterialApp(
      title: 'DevEnglish',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: Tts.mesajci,
      theme: tema(Brightness.light),
      darkTheme: tema(Brightness.dark),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final sayfalar = [
      HomePage(onGo: (i) => setState(() => _i = i)),
      const WordsPage(),
      const ListeningPage(),
      const SpeakingPage(),
      const ReadingPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _i, children: sayfalar),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Bugün',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Kelime',
          ),
          NavigationDestination(
            icon: Icon(Icons.hearing_outlined),
            selectedIcon: Icon(Icons.hearing),
            label: 'Dinle',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Konuş',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Oku',
          ),
        ],
      ),
    );
  }
}

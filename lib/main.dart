import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'favorites_page.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'player.dart';
import 'recording.dart';
import 'recordings_page.dart';
import 'store.dart';
import 'update.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (_) => const SizedBox.shrink(); // un errore in un riquadro non chiude l'app
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.designer1974.devoo_radio_kids.audio',
      androidNotificationChannelName: 'Devoo Radio Kids',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('Audio in background non disponibile: $e');
  }
  try {
    await Library.i.init().timeout(const Duration(seconds: 4));
  } catch (_) {}
  runApp(const KidsApp());
  unawaited(KidsStore.i.init());
  unawaited(RecController.i.recoverInterrupted()); // anche: segue le registrazioni programmate
  unawaited(Schedules.i.reload());
}

class KidsApp extends StatelessWidget {
  const KidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: yellow,
      brightness: Brightness.dark,
      primary: yellow,
      onPrimary: navy,
      surface: navy2,
    );
    return MaterialApp(
      title: 'Devoo Radio Kids',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: navy,
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: yellow,
          contentTextStyle: TextStyle(color: navy, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      locale: const Locale('it'),
      supportedLocales: const [Locale('it'), Locale('en'), Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  StreamSubscription<String>? _errors;
  StreamSubscription<String>? _recMsgs;
  // tornando nell'app: aggiorna registrazioni e programmi (possono essere finiti ad app chiusa)
  late final AppLifecycleListener _life = AppLifecycleListener(onResume: () {
    Recordings.i.reload();
    Schedules.i.reload();
  });

  @override
  void initState() {
    super.initState();
    _errors = RadioPlayer.i.errors.listen(_snack);
    _recMsgs = RecController.i.messages.listen(_snack);
    _life.hashCode; // avvia l'ascolto
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (mounted) checkForUpdate(context);
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  void dispose() {
    _life.dispose();
    _recMsgs?.cancel();
    _errors?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tabIndex,
      builder: (context, tab, _) => Scaffold(
        body: IndexedStack(
          index: tab,
          children: const [HomePage(), MapPage(), FavoritesPage(), RecordingsPage()],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RecBanner(),
            const MiniPlayer(),
            NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: navy2,
                indicatorColor: yellow,
                labelTextStyle: WidgetStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                ),
                iconTheme: WidgetStateProperty.resolveWith(
                  (s) => IconThemeData(color: s.contains(WidgetState.selected) ? navy : Colors.white70, size: 28),
                ),
              ),
              child: NavigationBar(
                height: 74,
                selectedIndex: tab,
                onDestinationSelected: (i) => tabIndex.value = i,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.radio_outlined), selectedIcon: Icon(Icons.radio), label: 'Radio'),
                  NavigationDestination(icon: Icon(Icons.public_outlined), selectedIcon: Icon(Icons.public), label: 'Mappa'),
                  NavigationDestination(
                      icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Preferiti'),
                  NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'Registrate'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

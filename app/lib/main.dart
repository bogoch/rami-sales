import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'background.dart';
import 'data.dart';
import 'screens/deals_screen.dart';
import 'settings.dart';
import 'updater.dart';
import 'watch.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = Settings();
  await settings.load();
  await Watchlist.instance.load();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await initNotifications();
      await initBackground();
    } catch (_) {
      // notifications/background are best-effort; the app works without them
    }
  }
  runApp(RamiSalesApp(settings: settings, api: Api(), updater: Updater()));
}

class RamiSalesApp extends StatelessWidget {
  final Settings settings;
  final Api api;
  final Updater updater;
  const RamiSalesApp({super.key, required this.settings, required this.api, required this.updater});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) {
      final cs = ColorScheme.fromSeed(
        seedColor: const Color(0xFFD62828),
        brightness: b,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      );
      return ThemeData(
        colorScheme: cs,
        useMaterial3: true,
        scaffoldBackgroundColor: b == Brightness.dark ? cs.surface : cs.surfaceContainer,
        splashFactory: NoSplash.splashFactory, // press feedback comes from scale, not ink ripples
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      );
    }
    return MaterialApp(
      title: 'מבצעי רמי',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      locale: const Locale('he', 'IL'),
      supportedLocales: const [Locale('he', 'IL')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: DealsScreen(settings: settings, api: api, updater: updater),
    );
  }
}

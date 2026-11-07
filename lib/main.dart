import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/backup.dart';
import 'core/license.dart';
import 'core/notifications.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await AppSettings.load();
  final prefs = await SharedPreferences.getInstance();
  themeMode.value = switch (prefs.getString('theme')) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
  runApp(const CashBookApp());
}

Future<void> setTheme(ThemeMode m) async {
  themeMode.value = m;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme', m.name);
}

class CashBookApp extends StatelessWidget {
  const CashBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (_, mode, _) => MaterialApp(
        title: 'كاش بوك',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: buildTheme(Pal.lightPal),
        darkTheme: buildTheme(Pal.darkPal),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          // Keep layout stable on phones with huge system font sizes.
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.of(context).textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
          ),
          child: child!,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    await NotificationService.I.init();
    final ok = await License.I.check();
    if (ok) {
      await AppStore.I.load();
      await BackupService.I.init();
      await NotificationService.I.rescheduleAll(AppStore.I.expenses);
    }
    final wait = const Duration(milliseconds: 1500) - DateTime.now().difference(started);
    if (!wait.isNegative) await Future.delayed(wait);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, _, _) => ok ? const HomeShell() : const LockScreen(),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final logo = CurvedAnimation(parent: _c, curve: const Interval(0, 0.6, curve: Curves.easeOutBack));
    final text = CurvedAnimation(parent: _c, curve: const Interval(0.35, 1, curve: Curves.easeOut));
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(scale: logo, child: const BrandMark(size: 96)),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: text,
              child: Column(children: [
                Text('كاش بوك',
                    style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 34, color: p.text)),
                const SizedBox(height: 6),
                Text('دفتر ديونك ومصاريفك بأناقة',
                    style: TextStyle(color: p.dim, fontWeight: FontWeight.w300, fontSize: 14.5)),
              ]),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: FadeTransition(
        opacity: text,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('تطوير', style: TextStyle(color: p.faint, fontSize: 12)),
              const SizedBox(height: 2),
              Text('أيهم الغزاوي',
                  style: TextStyle(fontFamily: kHead, color: p.gold, fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
          ),
        ),
      ),
    );
  }
}

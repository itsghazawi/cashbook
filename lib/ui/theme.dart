import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kHead = 'Alexandria';
const kBody = 'Plex';

class Pal {
  final Brightness b;
  final Color bg, bg2, card, cardHi, line, text, dim, faint;
  final Color gold, goldDeep, green, rose, blue, amber;
  final List<Color> hero;

  const Pal({
    required this.b,
    required this.bg,
    required this.bg2,
    required this.card,
    required this.cardHi,
    required this.line,
    required this.text,
    required this.dim,
    required this.faint,
    required this.gold,
    required this.goldDeep,
    required this.green,
    required this.rose,
    required this.blue,
    required this.amber,
    required this.hero,
  });

  bool get dark => b == Brightness.dark;

  static const darkPal = Pal(
    b: Brightness.dark,
    bg: Color(0xFF07100E),
    bg2: Color(0xFF0C1714),
    card: Color(0xFF111E1A),
    cardHi: Color(0xFF172823),
    line: Color(0x14FFFFFF),
    text: Color(0xFFF3EFE4),
    dim: Color(0xFF98ABA4),
    faint: Color(0xFF5D706A),
    gold: Color(0xFFDDB872),
    goldDeep: Color(0xFFA9813A),
    green: Color(0xFF3DD9A3),
    rose: Color(0xFFFF6F86),
    blue: Color(0xFF7DB3FF),
    amber: Color(0xFFFFB55C),
    hero: [Color(0xFF134A3D), Color(0xFF0B2721), Color(0xFF07130F)],
  );

  static const lightPal = Pal(
    b: Brightness.light,
    bg: Color(0xFFF4F1E8),
    bg2: Color(0xFFECE7DA),
    card: Color(0xFFFFFFFF),
    cardHi: Color(0xFFF8F5EE),
    line: Color(0x14000000),
    text: Color(0xFF10201B),
    dim: Color(0xFF5B6E67),
    faint: Color(0xFF9AA8A2),
    gold: Color(0xFFAE8638),
    goldDeep: Color(0xFF8A6624),
    green: Color(0xFF0B9E6C),
    rose: Color(0xFFDD3F5B),
    blue: Color(0xFF2F6FD6),
    amber: Color(0xFFD98A1F),
    hero: [Color(0xFF155C4B), Color(0xFF0E3A30), Color(0xFF0A2621)],
  );

  static Pal of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? darkPal : lightPal;
}

ThemeData buildTheme(Pal p) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: p.b,
    fontFamily: kBody,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.gold,
      brightness: p.b,
      primary: p.gold,
      surface: p.card,
      error: p.rose,
    ),
  );
  final t = base.textTheme;
  TextStyle? h(TextStyle? s, FontWeight w) => s?.copyWith(fontFamily: kHead, fontWeight: w, color: p.text);
  return base.copyWith(
    textTheme: t.copyWith(
      displayLarge: h(t.displayLarge, FontWeight.w800),
      displayMedium: h(t.displayMedium, FontWeight.w800),
      headlineLarge: h(t.headlineLarge, FontWeight.w700),
      headlineMedium: h(t.headlineMedium, FontWeight.w700),
      headlineSmall: h(t.headlineSmall, FontWeight.w700),
      titleLarge: h(t.titleLarge, FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: p.text),
      bodyLarge: t.bodyLarge?.copyWith(color: p.text),
      bodyMedium: t.bodyMedium?.copyWith(color: p.text),
      bodySmall: t.bodySmall?.copyWith(color: p.dim),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: p.text,
      systemOverlayStyle: p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, fontSize: 20, color: p.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.dark ? const Color(0xFF0E1A17) : const Color(0xFFF7F4EC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: TextStyle(color: p.dim, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: p.faint, fontWeight: FontWeight.w300),
      floatingLabelStyle: TextStyle(color: p.gold, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.gold, width: 1.4)),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.dark ? const Color(0xFF1E322C) : const Color(0xFF10201B),
      contentTextStyle: const TextStyle(fontFamily: kBody, color: Colors.white, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.bg2,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, fontSize: 19, color: p.text),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.bg : p.faint),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.gold : p.line),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}

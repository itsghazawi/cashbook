import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

/// Keeps the default USD rate up to date from sp-today.com whenever the phone
/// is online. The rate is saved locally, so the app keeps working offline and
/// the rate can still be typed by hand.
class RateService extends ChangeNotifier with WidgetsBindingObserver {
  RateService._();
  static final RateService I = RateService._();

  static const source = 'sp-today.com';
  static const _url = 'https://sp-today.com/currency/us_dollar';

  bool busy = false;
  String? lastError;
  bool _started = false;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString('rate_auto_at');
    AppStore.I.rateAutoAt = t == null ? null : DateTime.tryParse(t);
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      // Retry every few minutes: as soon as there is internet, the rate updates.
      Timer.periodic(const Duration(minutes: 5), (_) => _maybe());
    }
    unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  /// Fetch again unless we already have a fresh rate (less than 1 hour old).
  Future<void> _maybe() async {
    final at = AppStore.I.rateAutoAt;
    if (at != null && DateTime.now().difference(at) < const Duration(hours: 1)) return;
    await refresh();
  }

  /// Returns true when a new rate was saved.
  Future<bool> refresh() async {
    if (busy) return false;
    busy = true;
    notifyListeners();
    try {
      final r = await fetch();
      await AppStore.I.setLastRate(r, auto: true);
      lastError = null;
      return true;
    } catch (e) {
      lastError = e is TimeoutException || e is SocketException ? 'لا يوجد اتصال بالإنترنت' : 'تعذّر قراءة السعر من الموقع';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Sell price of the US dollar in new Syrian pounds.
  static Future<double> fetch() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.getUrl(Uri.parse(_url)).timeout(const Duration(seconds: 15));
      req.headers.set(HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36');
      req.headers.set(HttpHeaders.acceptLanguageHeader, 'ar');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw const FormatException('status');
      final html = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 20));
      return parse(html);
    } finally {
      client.close(force: true);
    }
  }

  /// Reads the page text: "شراء 143.50 ل.س جديدة 14,350 قديمة بيع 144.25 ل.س جديدة 14,425 قديمة".
  static double parse(String html) {
    final text = html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    double? num(String? s) => s == null ? null : double.tryParse(s.replaceAll(RegExp(r'[,٬]'), ''));

    // 1) Sell price in the NEW lira (two zeros removed), e.g. 144.25.
    final sell = RegExp(r'بيع\s*([\d.,]+)\s*ل\.س\s*جديدة').firstMatch(text);
    var v = num(sell?.group(1));
    // 2) Fallback: old-lira figure ÷ 100.
    if (v == null) {
      final all = RegExp(r'([\d][\d,٬]*)\s*قديمة').allMatches(text).map((m) => num(m.group(1))).whereType<double>()
          .where((x) => x > 1000).toList();
      if (all.isNotEmpty) v = (all.length > 1 ? all[1] : all[0]) / 100;
    }
    if (v == null || v < 10 || v > 100000) throw const FormatException('parse');
    return v;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifications.dart';

class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore I = AppStore._();

  final List<Person> people = [];
  final List<Txn> txns = [];
  final List<Expense> expenses = [];
  final List<Payment> payments = [];

  /// Last exchange rate entered (SYP per 1 USD) — pre-fills new entries.
  double lastRate = 0;
  int _nextNotif = 1;

  late File _file;
  late Directory _snapDir;
  bool loaded = false;

  Future<void> load() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/cashbook_data.json');
    _snapDir = Directory('${dir.path}/snapshots');
    if (!await _snapDir.exists()) await _snapDir.create(recursive: true);
    if (await _file.exists()) {
      try {
        _apply(jsonDecode(await _file.readAsString()) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('data load failed: $e');
        // Try the newest snapshot if the main file is damaged.
        final snaps = await listSnapshots();
        if (snaps.isNotEmpty) {
          _apply(jsonDecode(await snaps.first.readAsString())['data']);
        }
      }
    }
    loaded = true;
    await _dailySnapshot();
    notifyListeners();
  }

  // ---------- serialization ----------
  Map<String, dynamic> toJson() => {
        'schema': 1,
        'people': people.map((e) => e.toJson()).toList(),
        'txns': txns.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'payments': payments.map((e) => e.toJson()).toList(),
        'lastRate': lastRate,
        'nextNotif': _nextNotif,
      };

  void _apply(Map<String, dynamic> j) {
    people
      ..clear()
      ..addAll((j['people'] as List? ?? []).map((e) => Person.fromJson(Map<String, dynamic>.from(e))));
    txns
      ..clear()
      ..addAll((j['txns'] as List? ?? []).map((e) => Txn.fromJson(Map<String, dynamic>.from(e))));
    expenses
      ..clear()
      ..addAll((j['expenses'] as List? ?? []).map((e) => Expense.fromJson(Map<String, dynamic>.from(e))));
    payments
      ..clear()
      ..addAll((j['payments'] as List? ?? []).map((e) => Payment.fromJson(Map<String, dynamic>.from(e))));
    lastRate = (j['lastRate'] as num?)?.toDouble() ?? 0;
    _nextNotif = (j['nextNotif'] as num?)?.toInt() ??
        (expenses.isEmpty ? 1 : expenses.map((e) => e.notifBase).reduce((a, b) => a > b ? a : b) + 1);
  }

  /// Full backup envelope used for files and Google Drive.
  String exportBackup() => const JsonEncoder.withIndent(' ').convert({
        'app': 'cashbook',
        'by': 'Ayham Alghazawi',
        'exportedAt': DateTime.now().toIso8601String(),
        'data': toJson(),
      });

  /// Returns null on success, or an Arabic error message.
  Future<String?> importBackup(String raw) async {
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['app'] != 'cashbook' || j['data'] is! Map) {
        return 'الملف ليس نسخة احتياطية من كاش بوك';
      }
      await snapshotNow(); // keep a copy of current state before replacing
      _apply(Map<String, dynamic>.from(j['data']));
      await _save();
      await NotificationService.I.rescheduleAll(expenses);
      notifyListeners();
      return null;
    } catch (_) {
      return 'تعذّر قراءة الملف، تأكد أنه نسخة احتياطية صحيحة';
    }
  }

  Future<void> _save() async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(toJson()), flush: true);
    await tmp.rename(_file.path);
  }

  Future<void> _commit({bool expensesChanged = false}) async {
    notifyListeners();
    await _save();
    if (expensesChanged) await NotificationService.I.rescheduleAll(expenses);
    _markDirty();
  }

  // ---------- local snapshots (automatic safety copies) ----------
  Future<List<File>> listSnapshots() async {
    if (!await _snapDir.exists()) return [];
    final files = _snapDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> snapshotNow() async {
    final n = DateTime.now();
    final name = '${n.year}${_2(n.month)}${_2(n.day)}-${_2(n.hour)}${_2(n.minute)}${_2(n.second)}';
    await File('${_snapDir.path}/$name.json').writeAsString(exportBackup());
    final all = await listSnapshots();
    for (final f in all.skip(10)) {
      await f.delete();
    }
  }

  Future<void> _dailySnapshot() async {
    if (people.isEmpty && expenses.isEmpty) return;
    final snaps = await listSnapshots();
    final today = DateTime.now();
    final key = '${today.year}${_2(today.month)}${_2(today.day)}';
    if (snaps.isEmpty || !snaps.first.uri.pathSegments.last.startsWith(key)) {
      await snapshotNow();
    }
  }

  String _2(int v) => v.toString().padLeft(2, '0');

  // Drive auto-backup hook (set by backup service).
  VoidCallback? onDataChanged;
  void _markDirty() => onDataChanged?.call();

  Future<void> setLastRate(double r) async {
    if (r <= 0) return;
    lastRate = r;
    final p = await SharedPreferences.getInstance();
    await p.setDouble('lastRate', r);
    await _save();
  }

  // ---------- people ----------
  Person? person(String id) => people.where((p) => p.id == id).firstOrNull;

  Future<Person> addPerson(String name, String phone, {String note = ''}) async {
    final p = Person(id: newId(), name: name.trim(), phone: phone.trim(), note: note.trim());
    people.add(p);
    await _commit();
    return p;
  }

  Future<void> updatePerson(Person p) => _commit();

  Future<void> deletePerson(String id) async {
    people.removeWhere((p) => p.id == id);
    txns.removeWhere((t) => t.personId == id);
    await _commit();
  }

  // ---------- transactions ----------
  List<Txn> txnsOf(String personId) =>
      txns.where((t) => t.personId == personId).toList()..sort((a, b) => b.date.compareTo(a.date));

  Future<void> addTxn(Txn t) async {
    txns.add(t);
    if (t.rate != null && t.rate! > 0) lastRate = t.rate!;
    await _commit();
  }

  Future<void> updateTxn(Txn t) async {
    if (t.rate != null && t.rate! > 0) lastRate = t.rate!;
    await _commit();
  }

  Future<void> deleteTxn(String id) async {
    txns.removeWhere((t) => t.id == id);
    await _commit();
  }

  Balance balanceOf(String personId) {
    final b = Balance();
    for (final t in txns.where((t) => t.personId == personId)) {
      if (t.currency == 'USD') {
        b.usd += t.signed;
      } else {
        b.syp += t.signed;
        if (t.rate != null && t.rate! > 0) {
          b.sypAsUsdAtRates += t.signed / t.rate!;
        } else {
          // No rate saved with this entry: use the default rate if known.
          b.sypAllHaveRates = false;
          if (lastRate > 0) {
            b.sypAsUsdAtRates += t.signed / lastRate;
          } else {
            b.sypMissingRate = true;
          }
        }
      }
    }
    return b;
  }

  /// Totals: what others owe me (positive) and what I owe (negative), per currency.
  ({double meUsd, double meSyp, double onMeUsd, double onMeSyp}) totals() {
    double a = 0, b = 0, c = 0, d = 0;
    for (final p in people) {
      final bal = balanceOf(p.id);
      if (bal.usd > 0) a += bal.usd; else c += -bal.usd;
      if (bal.syp > 0) b += bal.syp; else d += -bal.syp;
    }
    return (meUsd: a, meSyp: b, onMeUsd: c, onMeSyp: d);
  }

  // ---------- expenses ----------
  Expense? expense(String id) => expenses.where((e) => e.id == id).firstOrNull;

  List<Expense> get activeExpenses =>
      expenses.where((e) => e.active && !e.done).toList()..sort((a, b) => a.due.compareTo(b.due));

  int takeNotifBase() => _nextNotif++;

  Future<void> addExpense(Expense e) async {
    expenses.add(e);
    await _commit(expensesChanged: true);
  }

  Future<void> updateExpense(Expense e) => _commit(expensesChanged: true);

  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((e) => e.id == id);
    payments.removeWhere((p) => p.expenseId == id);
    await _commit(expensesChanged: true);
  }

  Future<void> markPaid(Expense e, {double? amount}) async {
    payments.add(Payment(
      id: newId(),
      expenseId: e.id,
      amount: amount ?? e.amount,
      currency: e.currency,
      paidAt: DateTime.now(),
      dueAt: e.due,
    ));
    if (e.repeat == Repeat.none) {
      e.done = true;
    } else {
      e.due = e.repeat.next(e.due);
    }
    await _commit(expensesChanged: true);
  }

  List<Payment> paymentsOf(String expenseId) =>
      payments.where((p) => p.expenseId == expenseId).toList()..sort((a, b) => b.paidAt.compareTo(a.paidAt));

  ({double usd, double syp}) monthlyLoad() {
    double u = 0, s = 0;
    for (final e in expenses.where((e) => e.active && !e.done && e.repeat != Repeat.none)) {
      final v = e.amount * e.repeat.perMonth;
      if (e.currency == 'USD') u += v; else s += v;
    }
    return (usd: u, syp: s);
  }

  Future<void> wipeAll() async {
    await snapshotNow();
    people.clear();
    txns.clear();
    expenses.clear();
    payments.clear();
    await _commit(expensesChanged: true);
  }
}

import 'dart:math';

String newId() {
  final r = Random.secure();
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return '$t${r.nextInt(1 << 30).toRadixString(36)}';
}

class Person {
  final String id;
  String name;
  String phone;
  String note;
  final DateTime createdAt;

  Person({required this.id, required this.name, this.phone = '', this.note = '', DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'phone': phone, 'note': note, 'createdAt': createdAt.toIso8601String()};

  factory Person.fromJson(Map<String, dynamic> j) => Person(
        id: j['id'],
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        note: j['note'] ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );
}

/// gave = أعطيته (يزيد ما لي عليه) ، took = أخذت منه (يزيد ما علي له)
enum TxnKind { gave, took }

class Txn {
  final String id;
  final String personId;
  TxnKind kind;
  double amount;
  String currency;

  /// سعر الصرف يوم العملية: كم ليرة سورية مقابل 1 دولار
  double? rate;
  DateTime date;
  String note;

  Txn({
    required this.id,
    required this.personId,
    required this.kind,
    required this.amount,
    required this.currency,
    this.rate,
    required this.date,
    this.note = '',
  });

  /// + means the person owes me more, − means I owe them more.
  double get signed => kind == TxnKind.gave ? amount : -amount;

  /// Equivalent in the other currency using the day's rate.
  double? get usdValue {
    if (currency == 'USD') return amount;
    if (rate == null || rate! <= 0) return null;
    return amount / rate!;
  }

  double? get sypValue {
    if (currency == 'SYP') return amount;
    if (rate == null || rate! <= 0) return null;
    return amount * rate!;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'kind': kind.name,
        'amount': amount,
        'currency': currency,
        'rate': rate,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'],
        personId: j['personId'],
        kind: j['kind'] == 'took' ? TxnKind.took : TxnKind.gave,
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] ?? 'USD',
        rate: (j['rate'] as num?)?.toDouble(),
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        note: j['note'] ?? '',
      );
}

enum Repeat { none, weekly, monthly, yearly }

extension RepeatX on Repeat {
  String get label => switch (this) {
        Repeat.none => 'مرة واحدة',
        Repeat.weekly => 'أسبوعي',
        Repeat.monthly => 'شهري',
        Repeat.yearly => 'سنوي',
      };

  DateTime next(DateTime d) => switch (this) {
        Repeat.none => d,
        Repeat.weekly => d.add(const Duration(days: 7)),
        Repeat.monthly => _addMonths(d, 1),
        Repeat.yearly => _addMonths(d, 12),
      };

  /// Rough monthly weight for totals.
  double get perMonth => switch (this) {
        Repeat.none => 0,
        Repeat.weekly => 52 / 12,
        Repeat.monthly => 1,
        Repeat.yearly => 1 / 12,
      };
}

DateTime _addMonths(DateTime d, int n) {
  final total = d.month - 1 + n;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, min(d.day, lastDay), d.hour, d.minute);
}

/// Reminder offsets in minutes before the due time.
class Remind {
  static const day = 1440;
  static const half = 720;
  static const hour = 60;
  static const atTime = 0;
  static const all = [day, half, hour, atTime];

  static String label(int m) => switch (m) {
        day => 'قبل 24 ساعة',
        half => 'قبل 12 ساعة',
        hour => 'قبل ساعة',
        _ => 'عند الموعد',
      };

  static String short(int m) => switch (m) {
        day => '24س',
        half => '12س',
        hour => '1س',
        _ => 'الموعد',
      };
}

class Expense {
  final String id;
  String title;
  double amount;
  String currency;
  DateTime due;
  Repeat repeat;
  List<int> reminders;
  String note;
  bool active;
  int icon;

  /// Base id for scheduled notifications (notifBase*10 + slot).
  final int notifBase;
  bool done; // for one-time expenses after payment

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.due,
    this.repeat = Repeat.monthly,
    List<int>? reminders,
    this.note = '',
    this.active = true,
    this.icon = 0,
    required this.notifBase,
    this.done = false,
  }) : reminders = reminders ?? [Remind.day, Remind.half, Remind.hour];

  bool get overdue => !done && due.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'currency': currency,
        'due': due.toIso8601String(),
        'repeat': repeat.name,
        'reminders': reminders,
        'note': note,
        'active': active,
        'icon': icon,
        'notifBase': notifBase,
        'done': done,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'],
        title: j['title'] ?? '',
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] ?? 'USD',
        due: DateTime.tryParse(j['due'] ?? '') ?? DateTime.now(),
        repeat: Repeat.values.firstWhere((r) => r.name == j['repeat'], orElse: () => Repeat.monthly),
        reminders: (j['reminders'] as List?)?.map((e) => (e as num).toInt()).toList(),
        note: j['note'] ?? '',
        active: j['active'] ?? true,
        icon: j['icon'] ?? 0,
        notifBase: j['notifBase'] ?? 1,
        done: j['done'] ?? false,
      );
}

class Payment {
  final String id;
  final String expenseId;
  final double amount;
  final String currency;
  final DateTime paidAt;
  final DateTime dueAt;

  Payment({
    required this.id,
    required this.expenseId,
    required this.amount,
    required this.currency,
    required this.paidAt,
    required this.dueAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'expenseId': expenseId,
        'amount': amount,
        'currency': currency,
        'paidAt': paidAt.toIso8601String(),
        'dueAt': dueAt.toIso8601String(),
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'],
        expenseId: j['expenseId'],
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] ?? 'USD',
        paidAt: DateTime.parse(j['paidAt']),
        dueAt: DateTime.parse(j['dueAt']),
      );
}

/// Balance of one person, per currency.
class Balance {
  double usd = 0;
  double syp = 0;

  /// SYP part converted with each transaction's own rate.
  double sypAsUsdAtRates = 0;
  bool sypAllHaveRates = true;

  /// Some SYP entries have no rate and no default rate exists.
  bool sypMissingRate = false;

  /// Whole account in USD: USD part + SYP part at each entry's rate.
  double get totalUsd => usd + sypAsUsdAtRates;

  double of(String c) => c == 'USD' ? usd : syp;
  bool get isZero => usd.abs() < 0.005 && syp.abs() < 0.5;
}

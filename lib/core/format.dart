import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Currency codes used across the app.
class Cur {
  static const usd = 'USD';
  static const syp = 'SYP';

  static String symbol(String c) => c == usd ? r'$' : 'ل.س';
  static String name(String c) => c == usd ? 'دولار' : 'ليرة سورية';
}

final _num0 = NumberFormat('#,##0', 'en');
final _num2 = NumberFormat('#,##0.##', 'en');

String fmtNum(num v, {bool decimals = true}) {
  final a = v.abs();
  if (!decimals || a >= 1000000) return _num0.format(v);
  return _num2.format(v);
}

/// "1,250 $" or "100,000 ل.س" — symbol after the number reads well in RTL.
String fmtMoney(num v, String cur, {bool signed = false}) {
  final s = fmtNum(v.abs(), decimals: cur == Cur.usd);
  final sign = signed && v < 0 ? '−' : '';
  return cur == Cur.usd ? '$sign\$$s' : '$sign$s ل.س';
}

double? parseNum(String s) {
  final c = s.replaceAll(',', '').replaceAll('٬', '').trim();
  if (c.isEmpty) return null;
  return double.tryParse(_toLatinDigits(c));
}

String _toLatinDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    final j = fa.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (j >= 0) {
      b.write(j);
    } else if (ch == '٫') {
      b.write('.');
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

/// Groups thousands while typing: 100000 -> 100,000
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var t = _toLatinDigits(newValue.text).replaceAll(',', '');
    if (t.isEmpty) return newValue.copyWith(text: '');
    if (!RegExp(r'^\d*\.?\d{0,4}$').hasMatch(t)) return oldValue;
    final parts = t.split('.');
    final intPart = parts[0].isEmpty ? '0' : parts[0];
    final grouped = _num0.format(int.parse(intPart));
    final out = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}

const _months = [
  'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
  'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول'
];
const _days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String monthName(int m) => _months[m - 1];
String dayName(DateTime d) => _days[d.weekday - 1];

String fmtDateNum(DateTime d) => '${d.day}/${d.month}/${d.year}';

String fmtDate(DateTime d) => fmtDateNum(d);
String fmtDateShort(DateTime d) => '${d.day}/${d.month}';
String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'ص' : 'م'}';
}

String fmtDateTime(DateTime d) => '${dayName(d)}، ${fmtDate(d)} · ${fmtTime(d)}';

/// "بعد 3 أيام" / "منذ ساعتين"
String relative(DateTime target, {DateTime? now}) {
  now ??= DateTime.now();
  final diff = target.difference(now);
  final future = !diff.isNegative;
  final d = diff.abs();
  String unit;
  if (d.inMinutes < 1) return 'الآن';
  if (d.inMinutes < 60) {
    unit = _plural(d.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق');
  } else if (d.inHours < 24) {
    unit = _plural(d.inHours, 'ساعة', 'ساعتين', 'ساعات');
  } else if (d.inDays < 30) {
    unit = _plural(d.inDays, 'يوم', 'يومين', 'أيام');
  } else if (d.inDays < 365) {
    unit = _plural(d.inDays ~/ 30, 'شهر', 'شهرين', 'أشهر');
  } else {
    unit = _plural(d.inDays ~/ 365, 'سنة', 'سنتين', 'سنوات');
  }
  return future ? 'بعد $unit' : 'منذ $unit';
}

String _plural(int n, String one, String two, String few) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n <= 10) return '$n $few';
  return '$n $one';
}

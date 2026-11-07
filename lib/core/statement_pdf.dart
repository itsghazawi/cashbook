import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'format.dart';
import 'models.dart';
import 'store.dart';

/// Direction of the account from the owner's point of view.
enum StmtMood { theyOweMe, iOweThem, mixed, settled }

class StatementFonts {
  final pw.Font body, bodyBold, head, headBold, light;
  final pw.MemoryImage logo;
  StatementFonts(this.body, this.bodyBold, this.head, this.headBold, this.light, this.logo);

  static StatementFonts? _cache;

  static Future<StatementFonts> load([Future<ByteData> Function(String)? loader]) async {
    if (_cache != null) return _cache!;
    final l = loader ?? rootBundle.load;
    Future<pw.Font> f(String n) async => pw.Font.ttf(await l('assets/fonts/$n'));
    _cache = StatementFonts(
      await f('IBMPlexSansArabic-Regular.ttf'),
      await f('IBMPlexSansArabic-SemiBold.ttf'),
      await f('Alexandria-600.ttf'),
      await f('Alexandria-800.ttf'),
      await f('IBMPlexSansArabic-Light.ttf'),
      pw.MemoryImage((await l('assets/brand/icon.png')).buffer.asUint8List()),
    );
    return _cache!;
  }
}

class StatementPdf {
  static const _ink = PdfColor.fromInt(0xFF10201B);
  static const _dim = PdfColor.fromInt(0xFF5B6E67);
  static const _faint = PdfColor.fromInt(0xFF9AA8A2);
  static const _line = PdfColor.fromInt(0xFFE6E1D5);
  static const _paper = PdfColor.fromInt(0xFFFBF9F4);
  static const _emeraldDeep = PdfColor.fromInt(0xFF0B2A23);
  static const _emerald = PdfColor.fromInt(0xFF155C4B);
  static const _gold = PdfColor.fromInt(0xFFC79A4A);
  static const _goldSoft = PdfColor.fromInt(0xFFF6ECD6);
  static const _green = PdfColor.fromInt(0xFF0B9E6C);
  static const _greenSoft = PdfColor.fromInt(0xFFE3F5EE);
  static const _rose = PdfColor.fromInt(0xFFC8324F);
  static const _roseSoft = PdfColor.fromInt(0xFFFBE7EB);

  static StmtMood moodOf(Balance b, double rate) {
    if (b.isZero) return StmtMood.settled;
    final u = b.usd.abs() >= 0.005 ? b.usd.sign : 0;
    final s = b.syp.abs() >= 0.5 ? b.syp.sign : 0;
    if (u == 0) return s > 0 ? StmtMood.theyOweMe : StmtMood.iOweThem;
    if (s == 0 || s == u) return u > 0 ? StmtMood.theyOweMe : StmtMood.iOweThem;
    // Opposite signs: decide by the total in USD.
    if (b.sypMissingRate) return StmtMood.mixed;
    final total = b.totalUsd;
    if (total.abs() < 0.5) return StmtMood.mixed;
    return total > 0 ? StmtMood.theyOweMe : StmtMood.iOweThem;
  }

  static Future<Uint8List> build(Person person, {required String ownerName, StatementFonts? fonts}) async {
    final f = fonts ?? await StatementFonts.load();
    final s = AppStore.I;
    final bal = s.balanceOf(person.id);
    final txns = s.txnsOf(person.id).reversed.toList(); // oldest first
    final mood = moodOf(bal, s.lastRate);
    final now = DateTime.now();

    final accent = switch (mood) {
      StmtMood.theyOweMe => _green,
      StmtMood.iOweThem => _rose,
      _ => _gold,
    };
    final accentSoft = switch (mood) {
      StmtMood.theyOweMe => _greenSoft,
      StmtMood.iOweThem => _roseSoft,
      _ => _goldSoft,
    };
    final title = switch (mood) {
      StmtMood.theyOweMe => 'لي عليك',
      StmtMood.iOweThem => 'لك عندي',
      StmtMood.mixed => 'رصيد الحساب',
      StmtMood.settled => 'الحساب مسدد',
    };
    final message = switch (mood) {
      StmtMood.theyOweMe => 'نرجو التكرم بمراجعة الكشف وتسديد المبلغ المستحق، مع الشكر.',
      StmtMood.iOweThem => 'هذا المبلغ مستحق لكم لدينا، وسيتم تسديده بإذن الله.',
      StmtMood.mixed => 'تفاصيل الرصيد لكل عملة موضحة أدناه.',
      StmtMood.settled => 'لا يوجد أي مبلغ مستحق بين الطرفين حتى تاريخه.',
    };

    final theme = pw.ThemeData.withFont(base: f.body, bold: f.bodyBold, fontFallback: [f.head]);
    final doc = pw.Document(title: 'كشف حساب ${person.name}', author: 'كاش بوك - أيهم الغزاوي', creator: 'Cash Book');

    pw.TextStyle st(double size, {PdfColor color = _ink, pw.Font? font}) =>
        pw.TextStyle(font: font ?? f.body, fontSize: size, color: color);

    // ---- header band
    pw.Widget header() => pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 16),
          decoration: const pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [_emerald, _emeraldDeep],
              begin: pw.Alignment.topRight,
              end: pw.Alignment.bottomLeft,
            ),
          ),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.ClipRRect(
              horizontalRadius: 11,
              verticalRadius: 11,
              child: pw.Image(f.logo, width: 46, height: 46),
            ),
            pw.SizedBox(width: 12),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('كاش بوك', style: st(20, color: PdfColors.white, font: f.bodyBold)),
              pw.Text('CASH BOOK', style: st(8, color: _gold, font: f.head).copyWith(letterSpacing: 2.5)),
            ]),
            pw.Spacer(),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('كشف حساب', style: st(17, color: PdfColors.white, font: f.bodyBold)),
              pw.SizedBox(height: 2),
              pw.Text('تاريخ الإصدار: ${fmtDateNum(now)}  ·  ${fmtTime(now)}',
                  style: st(9, color: const PdfColor.fromInt(0xFFCFE0DA))),
            ]),
          ]),
        );

    pw.Widget party(String label, String name, String sub) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _line),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(label, style: st(9, color: _faint)),
              pw.SizedBox(height: 4),
              pw.Text(name, style: st(13.5, font: f.bodyBold)),
              if (sub.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(sub, style: st(10, color: _dim), textDirection: pw.TextDirection.ltr),
              ],
            ]),
          ),
        );

    // USD part in Syrian pounds, at each entry's rate (default rate when an entry has none).
    double usdAsSyp = 0;
    var usdMissing = false;
    for (final t in txns.where((t) => t.currency == Cur.usd)) {
      final r = (t.rate != null && t.rate! > 0) ? t.rate! : AppStore.I.lastRate;
      if (r > 0) {
        usdAsSyp += t.signed * r;
      } else {
        usdMissing = true;
      }
    }
    final showUsdAsSyp = !usdMissing && usdAsSyp.abs() >= 0.5;

    pw.Widget amountChip(double v, String cur) {
      final pos = v > 0;
      final c = pos ? _green : _rose;
      final label = pos ? 'لي عليك' : 'لك عندي';
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: c, width: 0.8),
        ),
        child: pw.Row(children: [
          pw.Container(width: 7, height: 7, decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle)),
          pw.SizedBox(width: 8),
          pw.Text(label, style: st(11, color: c, font: f.bodyBold)),
          pw.Spacer(),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(fmtMoney(v.abs(), cur), style: st(18, color: c, font: f.headBold)),
            if (cur == Cur.syp && !bal.sypMissingRate && bal.sypAsUsdAtRates.abs() > 0.004)
              pw.Text('تعادل ${fmtMoney(bal.sypAsUsdAtRates.abs(), Cur.usd)}', style: st(9.5, color: _dim, font: f.bodyBold)),
            if (cur == Cur.usd && showUsdAsSyp)
              pw.Text('تعادل بالسوري ${fmtMoney(usdAsSyp.abs(), Cur.syp)}', style: st(9.5, color: _dim, font: f.bodyBold)),
          ]),
        ]),
      );
    }

    final grand = bal.totalUsd;
    final showGrand = bal.syp.abs() >= 0.5 && !bal.sypMissingRate && mood != StmtMood.settled;

    pw.Widget grandTotal() {
      final pos = grand > 0;
      final c = grand.abs() < 0.005 ? _gold : (pos ? _green : _rose);
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: pw.BoxDecoration(color: _emeraldDeep, borderRadius: pw.BorderRadius.circular(12)),
        child: pw.Row(children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('المبلغ الكلي بالدولار', style: st(11.5, color: PdfColors.white, font: f.bodyBold)),
            pw.SizedBox(height: 2),
            pw.Text('الليرة السورية محسوبة على سعر الصرف المسجل لكل حركة',
                style: st(8, color: const PdfColor.fromInt(0xFFCFE0DA))),
          ]),
          pw.Spacer(),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(grand.abs() < 0.005 ? 'متعادل' : (pos ? 'لي عليك' : 'لك عندي'),
                style: st(9.5, color: c == _gold ? _gold : (pos ? const PdfColor.fromInt(0xFF7CF0C5) : const PdfColor.fromInt(0xFFFF9AAA)), font: f.bodyBold)),
            pw.Text(fmtMoney(grand.abs(), Cur.usd), style: st(20, color: _gold, font: f.headBold)),
          ]),
        ]),
      );
    }

    pw.Widget banner() => pw.Container(
          decoration: pw.BoxDecoration(color: accent, borderRadius: pw.BorderRadius.circular(16)),
          child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6),
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: accentSoft,
            borderRadius: pw.BorderRadius.circular(14),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Row(children: [
              pw.Container(
                width: 30,
                height: 30,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(color: accent, shape: pw.BoxShape.circle),
                child: pw.Text(
                  switch (mood) {
                    StmtMood.theyOweMe => '←',
                    StmtMood.iOweThem => '→',
                    _ => '=',
                  },
                  style: st(15, color: PdfColors.white, font: f.headBold),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(title, style: st(22, color: accent, font: f.bodyBold)),
            ]),
            pw.SizedBox(height: 6),
            pw.Text(message, style: st(10.5, color: _dim)),
            if (bal.usd.abs() >= 0.005) amountChip(bal.usd, Cur.usd),
            if (bal.syp.abs() >= 0.5) amountChip(bal.syp, Cur.syp),
          ]),
        ),
        );

    // ---- table
    final headStyle = st(9.5, color: PdfColors.white, font: f.bodyBold);
    pw.Widget cell(String t, {pw.TextStyle? style, pw.Alignment align = pw.Alignment.centerRight}) => pw.Container(
          alignment: align,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(t, style: style ?? st(10)),
        );

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _emeraldDeep),
        children: [
          cell('#', style: headStyle, align: pw.Alignment.center),
          cell('التاريخ', style: headStyle),
          cell('البيان', style: headStyle),
          cell('المبلغ', style: headStyle, align: pw.Alignment.centerLeft),
          cell('سعر الصرف', style: headStyle, align: pw.Alignment.center),
          cell('المعادل', style: headStyle, align: pw.Alignment.centerLeft),
        ],
      ),
    ];
    for (var i = 0; i < txns.length; i++) {
      final t = txns[i];
      final gave = t.kind == TxnKind.gave;
      final c = gave ? _green : _rose;
      final label = gave ? 'مبلغ سلم لك' : 'مبلغ استلم منك';
      String eq = '—';
      if (t.rate != null && t.rate! > 0) {
        eq = t.currency == Cur.syp ? fmtMoney(t.usdValue!, Cur.usd) : fmtMoney(t.sypValue!, Cur.syp);
      }
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _paper),
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          cell('${i + 1}', style: st(9, color: _faint), align: pw.Alignment.center),
          cell(fmtDateNum(t.date), style: st(9.5, color: _dim)),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(children: [
                pw.Container(width: 6, height: 6, decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle)),
                pw.SizedBox(width: 5),
                pw.Text(label, style: st(10, color: c, font: f.bodyBold)),
              ]),
              if (t.note.isNotEmpty) pw.Text(t.note, style: st(8.5, color: _dim)),
            ]),
          ),
          cell(fmtMoney(t.amount, t.currency), style: st(10.5, color: c, font: f.head), align: pw.Alignment.centerLeft),
          cell(t.rate != null && t.rate! > 0 ? fmtNum(t.rate!) : '—', style: st(9, color: _dim), align: pw.Alignment.center),
          cell(eq, style: st(9.5, color: _dim), align: pw.Alignment.centerLeft),
        ],
      ));
    }

    // ---- totals per currency
    pw.Widget totals() {
      final cols = <pw.Widget>[];
      for (final cur in [Cur.usd, Cur.syp]) {
        final list = txns.where((t) => t.currency == cur);
        if (list.isEmpty) continue;
        final given = list.where((t) => t.kind == TxnKind.gave).fold<double>(0, (a, t) => a + t.amount);
        final taken = list.where((t) => t.kind == TxnKind.took).fold<double>(0, (a, t) => a + t.amount);
        final net = given - taken;
        final c = net.abs() < 0.005 ? _dim : (net > 0 ? _green : _rose);
        cols.add(pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _line),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              pw.Text(cur == Cur.usd ? 'بالدولار' : 'بالليرة السورية', style: st(10.5, font: f.bodyBold, color: _gold)),
              pw.SizedBox(height: 6),
              _kv('مجموع ما سلم لك', fmtMoney(given, cur), st(9.5, color: _dim), st(10, color: _green, font: f.bodyBold)),
              _kv('مجموع ما استلم منك', fmtMoney(taken, cur), st(9.5, color: _dim), st(10, color: _rose, font: f.bodyBold)),
              pw.Divider(color: _line, height: 10),
              _kv(
                net.abs() < 0.005 ? 'الرصيد' : (net > 0 ? 'الرصيد: لي عليك' : 'الرصيد: لك عندي'),
                fmtMoney(net.abs(), cur),
                st(10, color: c, font: f.bodyBold),
                st(12, color: c, font: f.headBold),
              ),
              if (cur == Cur.usd && net.abs() >= 0.005 && showUsdAsSyp)
                _kv('تعادل بالسوري', fmtMoney(usdAsSyp.abs(), Cur.syp), st(10, color: c, font: f.bodyBold),
                    st(11, color: c, font: f.headBold)),
              if (cur == Cur.syp && net.abs() >= 0.5 && !bal.sypMissingRate)
                _kv('تعادل بالدولار', fmtMoney(bal.sypAsUsdAtRates.abs(), Cur.usd), st(10, color: c, font: f.bodyBold),
                    st(11, color: c, font: f.headBold)),
            ]),
          ),
        ));
        cols.add(pw.SizedBox(width: 10));
      }
      if (cols.isNotEmpty) cols.removeLast();
      return pw.Column(children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: cols),
        if (showGrand) pw.SizedBox(height: 10),
        if (showGrand) grandTotal(),
      ]);
    }

    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        buildBackground: (_) => pw.FullPage(ignoreMargins: true, child: pw.Container(color: _paper)),
      ),
      header: (ctx) => ctx.pageNumber == 1
          ? header()
          : pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 8),
              child: pw.Row(children: [
                pw.Text('كاش بوك · كشف حساب ${person.name}', style: st(9, color: _faint)),
              ]),
            ),
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(28, 8, 28, 16),
        child: pw.Column(children: [
          pw.Container(height: 0.6, color: _line),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Text('صادر من تطبيق كاش بوك', style: st(8.5, color: _dim, font: f.bodyBold)),
            pw.Text('  ·  تصميم وتطوير أيهم الغزاوي', style: st(8.5, color: _faint)),
            pw.Spacer(),
            pw.Text('صفحة ${ctx.pageNumber} من ${ctx.pagesCount}', style: st(8.5, color: _faint)),
          ]),
        ]),
      ),
      build: (ctx) => [
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 14, 28, 0),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Row(children: [
              party('إلى السيد / السيدة', person.name, ''),
              pw.SizedBox(width: 10),
              party('من', ownerName, ''),
            ]),
            pw.SizedBox(height: 14),
            banner(),
            pw.SizedBox(height: 12),
            pw.Row(children: [
              pw.Container(width: 4, height: 14, color: _gold),
              pw.SizedBox(width: 8),
              pw.Text('تفاصيل الحركات (${txns.length})', style: st(13, font: f.bodyBold)),
            ]),
            pw.SizedBox(height: 10),
          ]),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.ClipRRect(
            horizontalRadius: 10,
            verticalRadius: 10,
            child: pw.Table(
              border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
              columnWidths: const {
                0: pw.FixedColumnWidth(26),
                1: pw.FixedColumnWidth(82),
                2: pw.FlexColumnWidth(2.2),
                3: pw.FlexColumnWidth(1.5),
                4: pw.FixedColumnWidth(62),
                5: pw.FlexColumnWidth(1.3),
              },
              children: rows,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 12, 28, 0),
          child: totals(),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 10, 28, 0),
          child: pw.Text(
            'هذا الكشف صادر إلكترونيا للتوضيح والتذكير، ويعكس الحركات المسجلة حتى تاريخ الإصدار.',
            style: st(8.5, color: _faint, font: f.light),
          ),
        ),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _kv(String k, String v, pw.TextStyle ks, pw.TextStyle vs) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [pw.Text(k, style: ks), pw.Spacer(), pw.Text(v, style: vs)]),
      );

  static String fileName(Person p) {
    final safe = p.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    return 'كشف حساب - $safe.pdf';
  }

  static Future<void> share(Person person, {required String ownerName}) async {
    final bytes = await build(person, ownerName: ownerName);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${fileName(person)}');
    await file.writeAsBytes(bytes, flush: true);
    final bal = AppStore.I.balanceOf(person.id);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      text: summaryText(person, bal),
      title: 'كشف حساب ${person.name}',
    ));
  }

  static Future<bool> saveToDevice(Person person, {required String ownerName}) async {
    final bytes = await build(person, ownerName: ownerName);
    final uri = await FilePicker.saveFile(
      fileName: fileName(person),
      bytes: bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'حفظ كشف الحساب',
    );
    return uri != null;
  }

  static String summaryText(Person person, Balance bal) {
    final lines = <String>['مرحبا ${person.name} 👋'];
    final parts = <String>[];
    if (bal.usd.abs() >= 0.005) {
      parts.add('${bal.usd > 0 ? 'لي عليك' : 'لك عندي'}: ${fmtMoney(bal.usd.abs(), Cur.usd)}');
    }
    if (bal.syp.abs() >= 0.5) {
      parts.add('${bal.syp > 0 ? 'لي عليك' : 'لك عندي'}: ${fmtMoney(bal.syp.abs(), Cur.syp)}');
    }
    if (parts.isEmpty) {
      lines.add('حسابنا مسدد بالكامل حتى تاريخه ✅');
    } else {
      lines.add('ملخص حسابنا حتى ${fmtDateNum(DateTime.now())}:');
      lines.addAll(parts.map((e) => '• $e'));
    }
    lines.add('\n— مرسل من تطبيق كاش بوك');
    return lines.join('\n');
  }
}

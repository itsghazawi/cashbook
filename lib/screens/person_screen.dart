import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/statement_pdf.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'pdf_preview_screen.dart';
import 'person_forms.dart';
import 'settings_screen.dart';

class PersonScreen extends StatelessWidget {
  final String personId;
  final bool justCreated;
  const PersonScreen({super.key, required this.personId, this.justCreated = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        final person = s.person(personId);
        if (person == null) return const Scaffold();
        final bal = s.balanceOf(personId);
        final list = s.txnsOf(personId);
        final p = Pal.of(context);

        return Scaffold(
          body: AppBackground(
            child: SafeArea(
              child: CustomScrollView(slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: p.bg.withValues(alpha: 0.92),
                  title: Text(person.name),
                  actions: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      color: p.bg2,
                      onSelected: (v) => _menu(context, v, person),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('تعديل الاسم والرقم')),
                        PopupMenuItem(value: 'delete', child: Text('حذف الشخص وكل حركاته')),
                      ],
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                  sliver: SliverList.list(children: [
                    FadeIn(child: _Header(person: person, bal: bal)),
                    const SizedBox(height: 14),
                    FadeIn(
                      index: 1,
                      child: Row(children: [
                        Expanded(
                          child: _ActionBtn(
                            label: 'أعطيته',
                            hint: 'دين عليه / تسديد مني',
                            icon: Icons.arrow_upward_rounded,
                            color: p.green,
                            onTap: () => showTxnSheet(context, person, kind: TxnKind.gave),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionBtn(
                            label: 'أخذت منه',
                            hint: 'دين علي / تسديد منه',
                            icon: Icons.arrow_downward_rounded,
                            color: p.rose,
                            onTap: () => showTxnSheet(context, person, kind: TxnKind.took),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    FadeIn(
                      index: 2,
                      child: Row(children: [
                        Expanded(
                          child: GhostButton(
                            label: 'معاينة PDF',
                            icon: Icons.visibility_rounded,
                            color: p.gold,
                            onPressed: list.isEmpty ? null : () => _preview(context, person),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GoldButton(
                            label: 'إرسال PDF',
                            icon: Icons.send_rounded,
                            onPressed: list.isEmpty ? null : () => _share(context, person),
                          ),
                        ),
                      ]),
                    ),
                    SectionHeader('سجل الحركات (${list.length})'),
                  ]),
                ),
                if (list.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: justCreated ? 'تمت إضافة ${person.name}' : 'لا توجد حركات بعد',
                      subtitle: 'استخدم «أعطيته» أو «أخذت منه» لتسجيل أول مبلغ',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => FadeIn(index: i, child: _TxnTile(t: list[i], person: person)),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Future<void> _menu(BuildContext context, String v, Person person) async {
    if (v == 'edit') {
      final r = await showPersonSheet(context, edit: person);
      if (r == null) return;
      person
        ..name = r.$1
        ..phone = r.$2;
      await AppStore.I.updatePerson(person);
    } else if (v == 'delete') {
      if (!context.mounted) return;
      final ok = await confirm(context,
          title: 'حذف ${person.name}؟',
          message: 'سيتم حذف هذا الشخص وكل الحركات المسجلة معه نهائياً.',
          ok: 'حذف',
          danger: true);
      if (!ok || !context.mounted) return;
      Navigator.pop(context);
      await AppStore.I.deletePerson(person.id);
    }
  }

  Future<void> _preview(BuildContext context, Person person) async {
    final name = await ensureOwnerName(context);
    if (name == null || !context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewScreen(person: person, ownerName: name)));
  }

  // ignore: unused_element
  Future<void> _sendPdf(BuildContext context, Person person) async {
    final p = Pal.of(context);
    await showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetHeader('كشف حساب ${person.name}', subtitle: 'ملف PDF بتصميم كاش بوك يوضّح ما لك وما عليك'),
            GoldButton(
              label: 'مشاركة ملف PDF',
              icon: Icons.ios_share_rounded,
              onPressed: () async {
                Navigator.pop(c);
                await _share(context, person);
              },
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: 'معاينة / حفظ الملف',
              icon: Icons.download_rounded,
              onPressed: () async {
                Navigator.pop(c);
                await _save(context, person);
              },
            ),
            if (person.phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              GhostButton(
                label: 'فتح محادثة واتساب مع ${person.phone}',
                icon: Icons.chat_rounded,
                color: const Color(0xFF25D366),
                onPressed: () async {
                  Navigator.pop(c);
                  await _openWhatsApp(context, person);
                },
              ),
              const SizedBox(height: 8),
              Text('شارك ملف الـ PDF ثم اختر واتساب ومحادثة الشخص',
                  textAlign: TextAlign.center, style: TextStyle(color: p.faint, fontSize: 11.5)),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, Person person) async {
    final name = await ensureOwnerName(context);
    if (name == null || !context.mounted) return;
    try {
      await StatementPdf.share(person, ownerName: name);
    } catch (e) {
      if (context.mounted) toast(context, 'تعذّر إنشاء الملف', error: true);
    }
  }

  Future<void> _save(BuildContext context, Person person) async {
    final name = await ensureOwnerName(context);
    if (name == null || !context.mounted) return;
    final ok = await StatementPdf.saveToDevice(person, ownerName: name);
    if (context.mounted && ok) toast(context, 'تم حفظ الملف');
  }

  Future<void> _openWhatsApp(BuildContext context, Person person) async {
    final bal = AppStore.I.balanceOf(person.id);
    final text = StatementPdf.summaryText(person, bal);
    final num = waNumber(person.phone);
    final uri = Uri.parse('https://wa.me/$num?text=${Uri.encodeComponent(text)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      toast(context, 'تعذّر فتح واتساب', error: true);
    }
  }
}

/// 0992… → 963992…
String waNumber(String phone) {
  var d = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.startsWith('+')) return d.substring(1);
  if (d.startsWith('00')) return d.substring(2);
  if (d.startsWith('09')) return '963${d.substring(1)}';
  if (d.startsWith('9') && d.length == 9) return '963$d';
  return d;
}

class _Header extends StatelessWidget {
  final Person person;
  final Balance bal;
  const _Header({required this.person, required this.bal});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget row(double v, String cur) {
      final pos = v > 0;
      final c = pos ? p.green : p.rose;
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.withValues(alpha: p.dark ? 0.10 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.28)),
        ),
        child: Row(children: [
          Icon(pos ? Icons.south_west_rounded : Icons.north_east_rounded, color: c, size: 20),
          const SizedBox(width: 10),
          Text(pos ? 'لي عليه' : 'له علي', style: TextStyle(color: c, fontWeight: FontWeight.w600)),
          const Spacer(),
          MoneyText(v, cur, size: 22, color: c, weight: FontWeight.w800),
        ]),
      );
    }

    final usdTotal = bal.totalUsd;
    return Surface(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Avatar(person.name, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(person.name,
                  style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, fontSize: 19, color: p.text)),
              const SizedBox(height: 4),
              Text(person.phone.isEmpty ? 'بدون رقم' : person.phone,
                  textDirection: TextDirection.ltr, style: TextStyle(color: p.dim)),
            ]),
          ),
          if (person.phone.isNotEmpty) ...[
            _Circle(
              icon: Icons.call_rounded,
              color: p.blue,
              onTap: () => launchUrl(Uri.parse('tel:${person.phone}')),
            ),
            const SizedBox(width: 8),
            _Circle(
              icon: Icons.chat_rounded,
              color: const Color(0xFF25D366),
              onTap: () => launchUrl(Uri.parse('https://wa.me/${waNumber(person.phone)}'),
                  mode: LaunchMode.externalApplication),
            ),
          ],
        ]),
        if (bal.isZero)
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(Icons.task_alt_rounded, color: p.dim),
              const SizedBox(width: 10),
              Text('الحساب مسدَّد بالكامل', style: TextStyle(color: p.dim, fontWeight: FontWeight.w600)),
            ]),
          ),
        if (bal.usd.abs() >= 0.005) row(bal.usd, Cur.usd),
        if (bal.syp.abs() >= 0.5) row(bal.syp, Cur.syp),
        if (bal.syp.abs() >= 0.5 && !bal.sypMissingRate)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: p.hero, begin: Alignment.topRight, end: Alignment.bottomLeft),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('المبلغ الكلي بالدولار',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    bal.sypAllHaveRates ? 'السوري على سعر صرف كل حركة' : 'بعض الحركات على سعر الصرف الافتراضي',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10.5),
                  ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(usdTotal.abs() < 0.005 ? 'متعادل' : (usdTotal > 0 ? 'لي عليه' : 'له علي'),
                    style: TextStyle(color: usdTotal > 0 ? const Color(0xFF7CF0C5) : const Color(0xFFFF9AAA), fontSize: 11)),
                MoneyText(usdTotal, Cur.usd, size: 20, color: const Color(0xFFEBCB8B), weight: FontWeight.w800),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _Circle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Circle({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.14)),
          child: Icon(icon, color: color, size: 20),
        ),
      );
}

class _ActionBtn extends StatelessWidget {
  final String label, hint;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.hint, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Surface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      gradient: LinearGradient(
        colors: [color.withValues(alpha: p.dark ? 0.20 : 0.12), color.withValues(alpha: 0.04)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderColor: color.withValues(alpha: 0.3),
      child: Column(children: [
        Icon(icon, color: color),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, color: color, fontSize: 15.5)),
        const SizedBox(height: 3),
        Text(hint, style: TextStyle(color: p.dim, fontSize: 11)),
      ]),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final Txn t;
  final Person person;
  const _TxnTile({required this.t, required this.person});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final gave = t.kind == TxnKind.gave;
    final c = gave ? p.green : p.rose;
    String? eq;
    if (t.rate != null && t.rate! > 0) {
      eq = t.currency == Cur.syp ? '≈ ${fmtMoney(t.usdValue!, Cur.usd)}' : '≈ ${fmtMoney(t.sypValue!, Cur.syp)}';
    }
    return Surface(
      padding: const EdgeInsets.all(14),
      onTap: () => showTxnSheet(context, person, edit: t),
      onLongPress: () async {
        final ok = await confirm(context, title: 'حذف الحركة؟', message: 'لا يمكن التراجع عن الحذف.', ok: 'حذف', danger: true);
        if (ok) await AppStore.I.deleteTxn(t.id);
      },
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
          child: Icon(gave ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: c, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(gave ? 'أعطيته' : 'أخذت منه',
                style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w600, color: p.text)),
            const SizedBox(height: 3),
            Text(
              [fmtDate(t.date), if (t.note.isNotEmpty) t.note].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.dim, fontSize: 12),
            ),
            if (t.rate != null && t.rate! > 0)
              Text('سعر الصرف: ${fmtNum(t.rate!)} ل.س',
                  style: TextStyle(color: p.faint, fontSize: 11)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          MoneyText(t.amount, t.currency, size: 17, color: c),
          if (eq != null) Text(eq, style: TextStyle(color: p.gold, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

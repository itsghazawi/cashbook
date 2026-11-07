import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'expense_detail.dart';
import 'expenses_screen.dart';
import 'debts_screen.dart';

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int> onGo;
  const DashboardScreen({super.key, required this.onGo});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير';
    if (h < 18) return 'نهارك سعيد';
    return 'مساء الخير';
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        final t = s.totals();
        final upcoming = s.activeExpenses.take(3).toList();
        final ranked = s.people.map((x) => (x, s.balanceOf(x.id))).where((e) => !e.$2.isZero).toList()
          ..sort((a, b) => _weight(b.$2, s.lastRate).compareTo(_weight(a.$2, s.lastRate)));
        final load = s.monthlyLoad();
        final now = DateTime.now();

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
            children: [
              FadeIn(
                child: Row(children: [
                  const BrandMark(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_greeting(), style: TextStyle(color: p.dim, fontSize: 13)),
                      Text('كاش بوك',
                          style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 22, color: p.text)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(dayName(now), style: TextStyle(color: p.gold, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(fmtDateShort(now), style: TextStyle(color: p.dim, fontSize: 12.5)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              FadeIn(
                index: 1,
                child: GestureDetector(onTap: () => _showBreakdown(context, t), child: _HeroCard(t: t)),
              ),
              const SizedBox(height: 14),
              FadeIn(
                index: 2,
                child: Row(children: [
                  Expanded(
                    child: _MiniStat(
                      title: 'لي عند الناس',
                      icon: Icons.south_west_rounded,
                      color: p.green,
                      usd: t.meUsd,
                      syp: t.meSyp,
                      onTap: () => onGo(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      title: 'علي للناس',
                      icon: Icons.north_east_rounded,
                      color: p.rose,
                      usd: t.onMeUsd,
                      syp: t.onMeSyp,
                      onTap: () => onGo(1),
                    ),
                  ),
                ]),
              ),
              FadeIn(
                index: 3,
                child: SectionHeader('المواعيد القادمة', action: 'عرض الكل', onAction: () => onGo(2)),
              ),
              if (upcoming.isEmpty)
                FadeIn(
                  index: 3,
                  child: Surface(
                    onTap: () => onGo(2),
                    child: Row(children: [
                      Icon(Icons.event_available_rounded, color: p.gold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('لا توجد مصاريف دورية بعد — أضف الإيجار أو الفواتير ليذكّرك التطبيق قبل موعدها',
                            style: TextStyle(color: p.dim, height: 1.6, fontSize: 13)),
                      ),
                    ]),
                  ),
                )
              else
                ...upcoming.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeIn(
                        index: 4 + e.key,
                        child: ExpenseCard(
                          e: e.value,
                          compact: true,
                          onTap: () => showExpenseDetail(context, e.value),
                        ),
                      ),
                    )),
              if (load.usd > 0 || load.syp > 0) ...[
                const SizedBox(height: 4),
                FadeIn(
                  index: 6,
                  child: Surface(
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: p.amber.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.calendar_month_rounded, color: p.amber),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('التزاماتك الشهرية تقريباً', style: TextStyle(color: p.dim, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          Wrap(spacing: 14, children: [
                            if (load.usd > 0) MoneyText(load.usd, Cur.usd, size: 17),
                            if (load.syp > 0) MoneyText(load.syp, Cur.syp, size: 17),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ],
              if (ranked.isNotEmpty) ...[
                FadeIn(index: 7, child: SectionHeader('أبرز الحسابات', action: 'كل الأشخاص', onAction: () => onGo(1))),
                ...ranked.take(5).toList().asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeIn(index: 8 + e.key, child: PersonTile(person: e.value.$1, bal: e.value.$2)),
                    )),
              ],
              const SizedBox(height: 26),
              Center(
                child: Text('كاش بوك · تطوير أيهم الغزاوي',
                    style: TextStyle(color: p.faint, fontSize: 11.5, fontWeight: FontWeight.w300)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBreakdown(BuildContext context, ({double meUsd, double meSyp, double onMeUsd, double onMeSyp}) t) {
    final p = Pal.of(context);
    Widget block(String cur, double me, double onMe) {
      final net = me - onMe;
      final nc = net.abs() < 0.005 ? p.dim : (net > 0 ? p.green : p.rose);
      Widget row(String k, double v, Color c) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Text(k, style: TextStyle(color: p.dim, fontWeight: FontWeight.w500)),
              const Spacer(),
              MoneyText(v, cur, size: 18, color: c),
            ]),
          );
      return Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(cur == Cur.usd ? 'بالدولار' : 'بالليرة السورية',
              style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, color: p.gold)),
          const SizedBox(height: 6),
          row('لك (لي عند الناس)', me, p.green),
          row('عليك (علي للناس)', onMe, p.rose),
          Divider(color: p.line, height: 18),
          Row(children: [
            Text('صافي الحساب', style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(width: 8),
            if (net.abs() >= 0.005) Tag(net > 0 ? 'لك' : 'عليك', color: nc),
            const Spacer(),
            MoneyText(net, cur, size: 22, color: nc, weight: FontWeight.w800),
          ]),
        ]),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetHeader('تفاصيل الحساب'),
            block(Cur.usd, t.meUsd, t.onMeUsd),
            const SizedBox(height: 12),
            block(Cur.syp, t.meSyp, t.onMeSyp),
          ]),
        ),
      ),
    );
  }

  double _weight(Balance b, double rate) => b.usd.abs() + (rate > 0 ? b.syp.abs() / rate : b.syp.abs() / 1e6);
}

class _HeroCard extends StatelessWidget {
  final ({double meUsd, double meSyp, double onMeUsd, double onMeSyp}) t;
  const _HeroCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final netUsd = t.meUsd - t.onMeUsd;
    final netSyp = t.meSyp - t.onMeSyp;
    Widget line(double v, String cur) {
      final c = v.abs() < 0.005 ? Colors.white : (v > 0 ? const Color(0xFF7CF0C5) : const Color(0xFFFF9AAA));
      return Row(children: [
        Expanded(child: MoneyText(v, cur, size: cur == Cur.usd ? 34 : 24, color: c, weight: FontWeight.w800)),
        if (v.abs() >= 0.005)
          Tag(v > 0 ? 'لك' : 'عليك', color: c, icon: v > 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
      ]);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: p.hero, begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border.all(color: const Color(0xFFDDB872).withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: const Color(0xFF0B2A23).withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Stack(children: [
        Positioned(
          left: -40,
          top: -40,
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFFDDB872).withValues(alpha: 0.28),
                const Color(0xFFDDB872).withValues(alpha: 0),
              ]),
            ),
          ),
        ),
        Positioned(
          left: 18,
          bottom: 14,
          child: Icon(Icons.account_balance_wallet_rounded, size: 70, color: Colors.white.withValues(alpha: 0.05)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('صافي الحساب',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13.5, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDDB872).withValues(alpha: 0.5)),
                ),
                child: const Text('CASH BOOK',
                    style: TextStyle(fontFamily: kHead, fontSize: 10, letterSpacing: 2, color: Color(0xFFEBCB8B))),
              ),
            ]),
            const SizedBox(height: 16),
            line(netUsd, Cur.usd),
            const SizedBox(height: 6),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 8),
            line(netSyp, Cur.syp),
          ]),
        ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final double usd;
  final double syp;
  final VoidCallback onTap;
  const _MiniStat(
      {required this.title, required this.icon, required this.color, required this.usd, required this.syp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Surface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(color: p.dim, fontSize: 12.5, fontWeight: FontWeight.w500))),
        ]),
        const SizedBox(height: 12),
        MoneyText(usd, Cur.usd, size: 19, color: color),
        const SizedBox(height: 2),
        MoneyText(syp, Cur.syp, size: 15, color: color.withValues(alpha: 0.85), weight: FontWeight.w600),
      ]),
    );
  }
}

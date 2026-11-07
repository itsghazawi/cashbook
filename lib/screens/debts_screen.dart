import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'person_forms.dart';
import 'person_screen.dart';

enum _Filter { all, me, onMe }

class DebtsScreen extends StatefulWidget {
  final bool active;
  const DebtsScreen({super.key, this.active = true});
  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  _Filter _f = _Filter.all;
  String _q = '';
  final _search = TextEditingController();

  @override
  void didUpdateWidget(covariant DebtsScreen old) {
    super.didUpdateWidget(old);
    // Leaving the tab clears the search, so it starts fresh next time.
    if (old.active && !widget.active) {
      _search.clear();
      _q = '';
      _f = _Filter.all;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        final t = s.totals();
        var rows = s.people.map((x) => (x, s.balanceOf(x.id))).toList();
        if (_q.isNotEmpty) {
          rows = rows.where((r) => r.$1.name.contains(_q) || r.$1.phone.contains(_q)).toList();
        }
        rows = switch (_f) {
          _Filter.all => rows,
          _Filter.me => rows.where((r) => r.$2.usd > 0.004 || r.$2.syp > 0.4).toList(),
          _Filter.onMe => rows.where((r) => r.$2.usd < -0.004 || r.$2.syp < -0.4).toList(),
        };
        rows.sort((a, b) {
          final za = a.$2.isZero ? 1 : 0, zb = b.$2.isZero ? 1 : 0;
          if (za != zb) return za - zb;
          return a.$1.name.compareTo(b.$1.name);
        });

        return SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              sliver: SliverList.list(children: [
                Row(children: [
                  Expanded(
                    child: Text('الديون',
                        style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 26, color: p.text)),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => addPersonFlow(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    style: IconButton.styleFrom(backgroundColor: p.gold.withValues(alpha: 0.15), foregroundColor: p.gold),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _SumBox(label: 'لي', color: p.green, usd: t.meUsd, syp: t.meSyp)),
                  const SizedBox(width: 10),
                  Expanded(child: _SumBox(label: 'علي', color: p.rose, usd: t.onMeUsd, syp: t.onMeSyp)),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _q = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الرقم',
                    prefixIcon: Icon(Icons.search_rounded, color: p.faint),
                  ),
                ),
                const SizedBox(height: 12),
                Segmented<_Filter>(
                  value: _f,
                  onChanged: (v) => setState(() => _f = v),
                  items: [
                    (_Filter.all, 'الكل (${s.people.length})', null),
                    (_Filter.me, 'لي', p.green),
                    (_Filter.onMe, 'علي', p.rose),
                  ],
                ),
                const SizedBox(height: 14),
              ]),
            ),
            if (rows.isEmpty && _q.isNotEmpty && !s.people.any((x) => x.name == _q))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                  child: Column(children: [
                    Text('لا يوجد شخص بهذا الاسم', style: TextStyle(color: p.dim)),
                    const SizedBox(height: 14),
                    GoldButton(
                      label: 'إضافة «$_q» كشخص جديد',
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: () {
                        final name = _q;
                        _search.clear();
                        setState(() => _q = '');
                        addPersonFlow(context, name: name);
                      },
                    ),
                  ]),
                ),
              )
            else if (rows.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: s.people.isEmpty ? 'ابدأ بإضافة أول شخص' : 'لا توجد نتائج',
                  subtitle: s.people.isEmpty
                      ? 'أضف اسم الشخص ورقمه، ثم سجّل ما أعطيته أو ما أخذته منه بالدولار أو بالليرة'
                      : 'جرّب البحث باسم آخر أو غيّر الفلتر',
                  action: s.people.isEmpty
                      ? GoldButton(
                          label: 'إضافة شخص',
                          icon: Icons.person_add_alt_1_rounded,
                          expand: false,
                          onPressed: () => addPersonFlow(context),
                        )
                      : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                sliver: SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      FadeIn(index: i, child: PersonTile(person: rows[i].$1, bal: rows[i].$2)),
                ),
              ),
          ]),
        );
      },
    );
  }
}

class _SumBox extends StatelessWidget {
  final String label;
  final Color color;
  final double usd, syp;
  const _SumBox({required this.label, required this.color, required this.usd, required this.syp});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Surface(
      padding: const EdgeInsets.all(14),
      gradient: LinearGradient(
        colors: [color.withValues(alpha: p.dark ? 0.16 : 0.10), color.withValues(alpha: 0.02)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      borderColor: color.withValues(alpha: 0.25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontFamily: kHead, color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        MoneyText(usd, Cur.usd, size: 18, color: p.text),
        MoneyText(syp, Cur.syp, size: 14, color: p.dim, weight: FontWeight.w600),
      ]),
    );
  }
}

class PersonTile extends StatelessWidget {
  final Person person;
  final Balance bal;
  const PersonTile({super.key, required this.person, required this.bal});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget amt(double v, String cur) {
      final c = v > 0 ? p.green : p.rose;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Text(v > 0 ? 'لي ' : 'علي ', style: TextStyle(color: c.withValues(alpha: 0.8), fontSize: 11.5)),
        MoneyText(v, cur, size: 16, color: c),
      ]);
    }

    final parts = <Widget>[
      if (bal.usd.abs() >= 0.005) amt(bal.usd, Cur.usd),
      if (bal.syp.abs() >= 0.5) amt(bal.syp, Cur.syp),
    ];
    final tone = bal.isZero
        ? p.faint
        : (bal.usd > 0 || (bal.usd.abs() < 0.005 && bal.syp > 0))
            ? p.green
            : p.rose;
    return Surface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonScreen(personId: person.id))),
      child: Row(children: [
        Avatar(person.name, tone: tone),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w600, fontSize: 15.5, color: p.text)),
            const SizedBox(height: 3),
            Text(person.phone.isEmpty ? 'بدون رقم' : person.phone,
                textDirection: TextDirection.ltr, style: TextStyle(color: p.faint, fontSize: 12.5)),
          ]),
        ),
        if (parts.isEmpty)
          Tag('مسدَّد', color: p.faint, icon: Icons.check_rounded)
        else
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: parts),
      ]),
    );
  }
}

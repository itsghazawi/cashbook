import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'expense_detail.dart';
import 'expense_form.dart';

const expenseIcons = <IconData>[
  Icons.home_rounded,
  Icons.bolt_rounded,
  Icons.wifi_rounded,
  Icons.water_drop_rounded,
  Icons.phone_iphone_rounded,
  Icons.directions_car_rounded,
  Icons.school_rounded,
  Icons.local_gas_station_rounded,
  Icons.shopping_cart_rounded,
  Icons.medical_services_rounded,
  Icons.subscriptions_rounded,
  Icons.receipt_long_rounded,
];

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        final active = s.activeExpenses;
        final paused = s.expenses.where((e) => !e.active && !e.done).toList();
        final done = s.expenses.where((e) => e.done).toList();
        final load = s.monthlyLoad();
        final overdue = active.where((e) => e.overdue).length;

        return SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(children: [
                Expanded(
                  child: Text('المصاريف الشهرية',
                      style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 26, color: p.text)),
                ),
                IconButton.filledTonal(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseForm())),
                  icon: const Icon(Icons.add_alarm_rounded),
                  style: IconButton.styleFrom(backgroundColor: p.gold.withValues(alpha: 0.15), foregroundColor: p.gold),
                ),
              ]),
            ),
            Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(18, 4, 18, navClearance(context)),
            children: [
              Surface(
                gradient: LinearGradient(
                  colors: [p.gold.withValues(alpha: p.dark ? 0.18 : 0.14), p.gold.withValues(alpha: 0.03)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderColor: p.gold.withValues(alpha: 0.3),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('الالتزام الشهري التقريبي', style: TextStyle(color: p.dim, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      if (load.usd == 0 && load.syp == 0)
                        Text('—', style: TextStyle(color: p.text, fontSize: 20))
                      else
                        MoneyPair(usd: load.usd, syp: load.syp, size: 20, color: p.gold),
                    ]),
                  ),
                  Column(children: [
                    Text('${active.length}',
                        style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 24, color: p.text)),
                    Text('نشط', style: TextStyle(color: p.dim, fontSize: 11.5)),
                  ]),
                  if (overdue > 0) ...[
                    const SizedBox(width: 18),
                    Column(children: [
                      Text('$overdue',
                          style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 24, color: p.rose)),
                      Text('متأخر', style: TextStyle(color: p.rose, fontSize: 11.5)),
                    ]),
                  ],
                ]),
              ),
              if (active.isEmpty && paused.isEmpty)
                EmptyState(
                  icon: Icons.notifications_active_rounded,
                  title: 'لا تفوّت أي دفعة',
                  subtitle: 'أضف إيجار الدار أو الفواتير، حدد التاريخ والوقت، وسيذكّرك التطبيق قبل 24 ساعة وفي الموعد',
                  action: GoldButton(
                    label: 'إضافة مصروف',
                    icon: Icons.add_alarm_rounded,
                    expand: false,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseForm())),
                  ),
                )
              else ...[
                const SectionHeader('القادمة'),
                ...active.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeIn(
                        index: e.key,
                        child: ExpenseCard(e: e.value, onTap: () => showExpenseDetail(context, e.value)),
                      ),
                    )),
                if (paused.isNotEmpty) ...[
                  const SectionHeader('متوقفة مؤقتاً'),
                  ...paused.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Opacity(
                          opacity: 0.6,
                          child: ExpenseCard(e: e, onTap: () => showExpenseDetail(context, e)),
                        ),
                      )),
                ],
                if (done.isNotEmpty) ...[
                  const SectionHeader('مدفوعة (لمرة واحدة)'),
                  ...done.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Opacity(
                          opacity: 0.55,
                          child: ExpenseCard(e: e, onTap: () => showExpenseDetail(context, e)),
                        ),
                      )),
                ],
              ],
            ],
          ),
            ),
          ]),
        );
      },
    );
  }
}

class ExpenseCard extends StatelessWidget {
  final Expense e;
  final bool compact;
  final VoidCallback? onTap;
  const ExpenseCard({super.key, required this.e, this.compact = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final now = DateTime.now();
    final left = e.due.difference(now);
    final overdue = e.overdue;
    final soon = !overdue && left.inHours < 48;
    final c = e.done
        ? p.faint
        : overdue
            ? p.rose
            : soon
                ? p.amber
                : p.green;
    // progress through the current period, for the ring
    final period = switch (e.repeat) {
      Repeat.weekly => const Duration(days: 7),
      Repeat.monthly => const Duration(days: 30),
      Repeat.yearly => const Duration(days: 365),
      Repeat.none => const Duration(days: 30),
    };
    final prog = overdue ? 1.0 : (1 - left.inMinutes / period.inMinutes).clamp(0.04, 1.0);

    return Surface(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Row(children: [
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: e.done ? 1 : prog.toDouble(),
              strokeWidth: 3,
              color: c,
              backgroundColor: c.withValues(alpha: 0.12),
              strokeCap: StrokeCap.round,
            ),
            Icon(expenseIcons[e.icon.clamp(0, expenseIcons.length - 1)], color: c, size: 22),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w600, fontSize: 15.5, color: p.text)),
              ),
              const SizedBox(width: 8),
              Tag(e.repeat.label, color: p.blue),
              if (!e.done && AppSettings.reminders.value.isNotEmpty) ...[
                const SizedBox(width: 6),
                Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 3),
                  message: 'التذكير: ${AppSettings.reminders.value.map(Remind.label).join('، ')}',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: p.gold.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(Icons.notifications_active_rounded, size: 14, color: p.gold),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 5),
            Text(
              e.done ? 'تم الدفع' : '${fmtDateShort(e.due)} · ${fmtTime(e.due)}',
              style: TextStyle(color: p.dim, fontSize: 12.5),
            ),

          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          MoneyText(e.amount, e.currency, size: 17, color: p.text),
          const SizedBox(height: 4),
          if (!e.done)
            Text(
              overdue ? 'متأخر ${relative(e.due).replaceFirst('منذ ', '')}' : relative(e.due),
              style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
            ),
        ]),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'expense_form.dart';
import 'expenses_screen.dart';

Future<void> showExpenseDetail(BuildContext context, Expense e) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ExpenseDetail(expenseId: e.id),
  );
}

class _ExpenseDetail extends StatelessWidget {
  final String expenseId;
  const _ExpenseDetail({required this.expenseId});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final e = AppStore.I.expense(expenseId);
        if (e == null) return const SizedBox(height: 100);
        final pays = AppStore.I.paymentsOf(e.id);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (context, ctrl) => ListView(
            controller: ctrl,
            padding: EdgeInsets.fromLTRB(20, 0, 20, 30 + bottomGap(context)),
            children: [
              const SheetHeader('تفاصيل المصروف'),
              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: p.gold.withValues(alpha: 0.14),
                    border: Border.all(color: p.gold.withValues(alpha: 0.35)),
                  ),
                  child: Icon(expenseIcons[e.icon.clamp(0, expenseIcons.length - 1)], color: p.gold, size: 32),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(e.title,
                    style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 22, color: p.text)),
              ),
              const SizedBox(height: 4),
              Center(child: MoneyText(e.amount, e.currency, size: 26, color: p.gold, weight: FontWeight.w800)),
              const SizedBox(height: 16),
              Surface(
                child: Column(children: [
                  _Row(Icons.event_rounded, 'الموعد', e.done ? 'تم الدفع' : fmtDateTime(e.due)),
                  if (!e.done)
                    _Row(Icons.hourglass_bottom_rounded, 'المتبقي', e.overdue ? 'متأخر' : relative(e.due),
                        color: e.overdue ? p.rose : null),
                  _Row(Icons.repeat_rounded, 'التكرار', e.repeat.label),
                  if (e.note.isNotEmpty) _Row(Icons.notes_rounded, 'ملاحظة', e.note),
                ]),
              ),
              const SizedBox(height: 16),
              if (!e.done && e.active)
                GoldButton(
                  label: 'تم الدفع',
                  icon: Icons.task_alt_rounded,
                  color: p.green,
                  textColor: Colors.white,
                  onPressed: () async {
                    final ok = await confirm(
                      context,
                      title: 'تأكيد الدفع',
                      message: e.repeat == Repeat.none
                          ? 'سيتم تسجيل الدفعة وإنهاء هذا المصروف.'
                          : 'سيتم تسجيل الدفعة، ونقل الموعد القادم إلى ${fmtDateTime(e.repeat.next(e.due))}.',
                      ok: 'تم الدفع',
                    );
                    if (!ok) return;
                    HapticFeedback.mediumImpact();
                    final nav = Navigator.of(context);
                    final root = nav.context;
                    await AppStore.I.markPaid(e);
                    nav.pop();
                    if (root.mounted) await showDoneTick(root, 'تم الدفع');
                  },
                ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: GhostButton(
                    label: 'تعديل',
                    icon: Icons.edit_rounded,
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseForm(edit: e)));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GhostButton(
                    label: e.active ? 'إيقاف مؤقت' : 'استئناف',
                    icon: e.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    onPressed: () async {
                      e.active = !e.active;
                      await AppStore.I.updateExpense(e);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              GhostButton(
                label: 'حذف المصروف',
                icon: Icons.delete_outline_rounded,
                color: p.rose,
                onPressed: () async {
                  final ok = await confirm(context,
                      title: 'حذف ${e.title}؟', message: 'سيتم حذف المصروف وسجل دفعاته وإلغاء تذكيراته.', ok: 'حذف', danger: true);
                  if (!ok || !context.mounted) return;
                  Navigator.pop(context);
                  await AppStore.I.deleteExpense(e.id);
                },
              ),
              SectionHeader('سجل الدفعات (${pays.length})'),
              if (pays.isEmpty)
                Text('لم تُسجّل أي دفعة بعد', style: TextStyle(color: p.faint))
              else
                ...pays.map((x) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Surface(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Icon(Icons.check_circle_rounded, color: p.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('دُفعت ${fmtDate(x.paidAt)}', style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
                              Text('عن موعد ${fmtDate(x.dueAt)}', style: TextStyle(color: p.faint, fontSize: 11.5)),
                            ]),
                          ),
                          MoneyText(x.amount, x.currency, size: 15),
                        ]),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String k, v;
  final Color? color;
  const _Row(this.icon, this.k, this.v, {this.color});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: p.faint),
        const SizedBox(width: 10),
        SizedBox(width: 70, child: Text(k, style: TextStyle(color: p.dim, fontSize: 13))),
        Expanded(
          child: Text(v, style: TextStyle(color: color ?? p.text, fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.4)),
        ),
      ]),
    );
  }
}

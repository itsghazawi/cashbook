import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'expenses_screen.dart';

class ExpenseForm extends StatefulWidget {
  final Expense? edit;
  const ExpenseForm({super.key, this.edit});
  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  late final _title = TextEditingController(text: widget.edit?.title ?? '');
  late final _amount = TextEditingController(text: widget.edit == null ? '' : fmtNum(widget.edit!.amount));
  late final _note = TextEditingController(text: widget.edit?.note ?? '');
  late String _cur = widget.edit?.currency ?? Cur.usd;
  late Repeat _repeat = widget.edit?.repeat ?? Repeat.monthly;
  late int _icon = widget.edit?.icon ?? 0;
  late DateTime _due = widget.edit?.due ?? _defaultDue();
  String? _errTitle, _errAmount;

  static DateTime _defaultDue() {
    final n = DateTime.now().add(const Duration(days: 1));
    return DateTime(n.year, n.month, n.day, 10, 0);
  }

  static const _presets = [
    ('إيجار الدار', 0),
    ('الكهرباء', 1),
    ('الإنترنت', 2),
    ('المياه', 3),
    ('رصيد الجوال', 4),
    ('قسط السيارة', 5),
    ('أقساط المدرسة', 6),
  ];

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _due = DateTime(d.year, d.month, d.day, _due.hour, _due.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    if (t != null) setState(() => _due = DateTime(_due.year, _due.month, _due.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    final a = parseNum(_amount.text);
    setState(() {
      _errTitle = _title.text.trim().isEmpty ? 'اكتب اسم المصروف' : null;
      _errAmount = (a == null || a <= 0) ? 'أدخل المبلغ' : null;
    });
    if (_errTitle != null || _errAmount != null) return;

    final ordered = Remind.all.toList();
    final s = AppStore.I;
    if (widget.edit != null) {
      final e = widget.edit!
        ..title = _title.text.trim()
        ..amount = a!
        ..currency = _cur
        ..due = _due
        ..repeat = _repeat
        ..reminders = ordered
        ..note = _note.text.trim()
        ..icon = _icon
        ..done = false;
      await s.updateExpense(e);
    } else {
      await s.addExpense(Expense(
        id: newId(),
        title: _title.text.trim(),
        amount: a!,
        currency: _cur,
        due: _due,
        repeat: _repeat,
        reminders: ordered,
        note: _note.text.trim(),
        icon: _icon,
        notifBase: s.takeNotifBase(),
      ));
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    toast(context, widget.edit == null ? 'تمت إضافة المصروف وجدولة التذكيرات' : 'تم حفظ التعديلات');
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.edit == null ? 'مصروف دوري جديد' : 'تعديل المصروف')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(18, 6, 18, 40 + MediaQuery.of(context).viewPadding.bottom),
        children: [
          if (widget.edit == null) ...[
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final pr = _presets[i];
                  return ActionChip(
                    label: Text(pr.$1),
                    avatar: Icon(expenseIcons[pr.$2], size: 16, color: p.gold),
                    backgroundColor: p.card,
                    side: BorderSide(color: p.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    onPressed: () => setState(() {
                      _title.text = pr.$1;
                      _icon = pr.$2;
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: 'اسم المصروف',
              hintText: 'مثلاً: إيجار الدار',
              errorText: _errTitle,
              prefixIcon: Icon(expenseIcons[_icon], color: p.gold),
            ),
          ),
          const SizedBox(height: 14),
          Text('الأيقونة', style: TextStyle(color: p.dim, fontSize: 12.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(expenseIcons.length, (i) {
              final sel = i == _icon;
              return GestureDetector(
                onTap: () => setState(() => _icon = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: sel ? p.gold.withValues(alpha: 0.18) : p.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sel ? p.gold : p.line),
                  ),
                  child: Icon(expenseIcons[i], color: sel ? p.gold : p.dim, size: 21),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          Segmented<String>(
            value: _cur,
            onChanged: (v) => setState(() => _cur = v),
            items: const [(Cur.usd, 'دولار  \$', null), (Cur.syp, 'ليرة سورية', null)],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [ThousandsFormatter()],
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kHead, fontSize: 28, fontWeight: FontWeight.w800, color: p.gold),
            decoration: InputDecoration(hintText: '0', errorText: _errAmount, suffixText: Cur.symbol(_cur)),
          ),
          const SectionHeader('موعد الدفع'),
          Row(children: [
            Expanded(
              child: _PickBox(icon: Icons.event_rounded, label: 'التاريخ', value: fmtDate(_due), onTap: _pickDate),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PickBox(icon: Icons.schedule_rounded, label: 'الوقت', value: fmtTime(_due), onTap: _pickTime),
            ),
          ]),
          const SizedBox(height: 12),
          Segmented<Repeat>(
            value: _repeat,
            onChanged: (v) => setState(() => _repeat = v),
            items: [for (final r in [Repeat.monthly, Repeat.weekly, Repeat.yearly, Repeat.none]) (r, r.label, null)],
          ),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.notifications_active_rounded, size: 16, color: p.faint),
            const SizedBox(width: 6),
            Expanded(
              child: Text('التذكير قبل 24 ساعة وفي الموعد نفسه — تقدر تغيّره من الإعدادات',
                  style: TextStyle(color: p.faint, fontSize: 11.5, height: 1.5)),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', prefixIcon: Icon(Icons.notes_rounded)),
          ),
          const SizedBox(height: 24),
          GoldButton(label: 'حفظ', icon: Icons.check_rounded, onPressed: _save),
        ],
      ),
    );
  }
}

class _PickBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  const _PickBox({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Surface(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(icon, color: p.gold, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: p.faint, fontSize: 11.5)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w600, color: p.text, fontSize: 14)),
          ]),
        ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'person_screen.dart';

/// Add a new person, then open their page.
Future<void> addPersonFlow(BuildContext context, {String name = ''}) async {
  final r = await showPersonSheet(context, initialName: name);
  if (r == null || !context.mounted) return;
  final person = await AppStore.I.addPerson(r.$1, r.$2);
  if (!context.mounted) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => PersonScreen(personId: person.id, justCreated: true)));
}

Future<(String, String)?> showPersonSheet(BuildContext context, {Person? edit, String initialName = ''}) {
  final name = TextEditingController(text: edit?.name ?? initialName);
  final phone = TextEditingController(text: edit?.phone ?? '');
  String? err;
  return showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetHeader(edit == null ? 'شخص جديد' : 'تعديل البيانات'),
            TextField(
              controller: name,
              autofocus: edit == null,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'الاسم',
                errorText: err,
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (واتساب)',
                hintText: '09xxxxxxxx',
                prefixIcon: Icon(Icons.phone_iphone_rounded),
              ),
            ),
            const SizedBox(height: 20),
            GoldButton(
              label: edit == null ? 'إضافة' : 'حفظ',
              icon: Icons.check_rounded,
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  setS(() => err = 'اكتب الاسم');
                  return;
                }
                Navigator.pop(c, (name.text.trim(), phone.text.trim()));
              },
            ),
          ]),
        ),
      ),
    ),
  );
}

/// Quick add → "دين جديد": choose an existing person, then record the amount.
Future<void> newDebtFlow(BuildContext context) async {
  final s = AppStore.I;
  if (s.people.isEmpty) {
    toast(context, 'أضف شخصاً أولاً');
    await addPersonFlow(context);
    return;
  }
  final person = await showModalBottomSheet<Person>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _PersonPicker(),
  );
  if (person == null || !context.mounted) return;
  await showTxnSheet(context, person, kind: TxnKind.gave);
}

class _PersonPicker extends StatefulWidget {
  const _PersonPicker();
  @override
  State<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<_PersonPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final s = AppStore.I;
    final list = s.people.where((x) => _q.isEmpty || x.name.contains(_q) || x.phone.contains(_q)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, ctrl) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          const SheetHeader('دين جديد', subtitle: 'اختر الشخص'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: InputDecoration(hintText: 'ابحث بالاسم أو الرقم', prefixIcon: Icon(Icons.search_rounded, color: p.faint)),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                for (final x in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Surface(
                      padding: const EdgeInsets.all(12),
                      onTap: () => Navigator.pop(context, x),
                      child: Row(children: [
                        Avatar(x.name, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(x.name, style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w600, color: p.text)),
                            if (x.phone.isNotEmpty)
                              Text(x.phone, textDirection: TextDirection.ltr, style: TextStyle(color: p.faint, fontSize: 12)),
                          ]),
                        ),
                        Icon(Icons.chevron_left_rounded, color: p.faint),
                      ]),
                    ),
                  ),
                if (list.isEmpty && _q.isNotEmpty)
                  GoldButton(
                    label: 'إضافة «$_q» كشخص جديد',
                    icon: Icons.person_add_alt_1_rounded,
                    onPressed: () async {
                      final person = await AppStore.I.addPerson(_q, '');
                      if (context.mounted) Navigator.pop(context, person);
                    },
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Add / edit a debt movement.
Future<void> showTxnSheet(BuildContext context, Person person, {TxnKind kind = TxnKind.gave, Txn? edit}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TxnSheet(person: person, kind: edit?.kind ?? kind, edit: edit),
  );
}

class _TxnSheet extends StatefulWidget {
  final Person person;
  final TxnKind kind;
  final Txn? edit;
  const _TxnSheet({required this.person, required this.kind, this.edit});
  @override
  State<_TxnSheet> createState() => _TxnSheetState();
}

class _TxnSheetState extends State<_TxnSheet> {
  late TxnKind _kind = widget.kind;
  late String _cur = widget.edit?.currency ?? Cur.usd;
  late final _amount = TextEditingController(
      text: widget.edit == null ? '' : fmtNum(widget.edit!.amount));
  late final _rate = TextEditingController(text: _initialRate());
  late final _note = TextEditingController(text: widget.edit?.note ?? '');
  late DateTime _date = widget.edit?.date ?? DateTime.now();
  String? _err;

  String _initialRate() {
    final r = widget.edit?.rate ?? AppStore.I.lastRate;
    return r > 0 ? fmtNum(r) : '';
  }

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
    _rate.addListener(() => setState(() {}));
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
  }

  Future<void> _save() async {
    final a = parseNum(_amount.text);
    if (a == null || a <= 0) {
      setState(() => _err = 'أدخل المبلغ');
      return;
    }
    final r = parseNum(_rate.text);
    final rate = (r != null && r > 0) ? r : null;
    if (widget.edit != null) {
      final t = widget.edit!
        ..kind = _kind
        ..amount = a
        ..currency = _cur
        ..rate = rate
        ..date = _date
        ..note = _note.text.trim();
      await AppStore.I.updateTxn(t);
    } else {
      await AppStore.I.addTxn(Txn(
        id: newId(),
        personId: widget.person.id,
        kind: _kind,
        amount: a,
        currency: _cur,
        rate: rate,
        date: _date,
        note: _note.text.trim(),
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final a = parseNum(_amount.text);
    final r = parseNum(_rate.text);
    String? equiv;
    if (a != null && a > 0 && r != null && r > 0) {
      equiv = _cur == Cur.syp ? 'تعادل ≈ ${fmtMoney(a / r, Cur.usd)}' : 'تعادل ≈ ${fmtMoney(a * r, Cur.syp)}';
    }
    final kc = _kind == TxnKind.gave ? p.green : p.rose;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHeader(widget.edit == null ? 'حركة جديدة' : 'تعديل الحركة', subtitle: widget.person.name),
          Segmented<TxnKind>(
            value: _kind,
            onChanged: (v) => setState(() => _kind = v),
            items: [
              (TxnKind.gave, 'أعطيته', p.green),
              (TxnKind.took, 'أخذت منه', p.rose),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _kind == TxnKind.gave
                ? 'دين جديد عليه، أو تسديد مني له — يزيد ما لي عليه'
                : 'دين جديد علي، أو تسديد منه لي — يزيد ما له علي',
            textAlign: TextAlign.center,
            style: TextStyle(color: kc.withValues(alpha: 0.85), fontSize: 12),
          ),
          const SizedBox(height: 18),
          Segmented<String>(
            value: _cur,
            onChanged: (v) => setState(() => _cur = v),
            items: const [(Cur.usd, 'دولار  \$', null), (Cur.syp, 'ليرة سورية', null)],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [ThousandsFormatter()],
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kHead, fontSize: 30, fontWeight: FontWeight.w800, color: kc),
            decoration: InputDecoration(
              hintText: '0',
              errorText: _err,
              suffixText: Cur.symbol(_cur),
              suffixStyle: TextStyle(color: p.dim, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [ThousandsFormatter()],
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'سعر صرف الدولار اليوم (اختياري)',
              hintText: 'مثلاً 13,000',
              suffixText: 'ل.س / \$1',
              prefixIcon: const Icon(Icons.currency_exchange_rounded),
              helperText: 'يُستخدم لمعرفة قيمة المبلغ بالعملة الأخرى يوم العملية',
              helperStyle: TextStyle(color: p.faint, fontSize: 11),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: equiv == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: p.gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.swap_horiz_rounded, color: p.gold),
                      const SizedBox(width: 10),
                      Text(equiv,
                          style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, color: p.gold, fontSize: 16)),
                    ]),
                  ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'التاريخ', prefixIcon: Icon(Icons.event_rounded)),
              child: Text(fmtDate(_date), style: TextStyle(color: p.text)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', prefixIcon: Icon(Icons.notes_rounded)),
          ),
          const SizedBox(height: 22),
          GoldButton(label: 'حفظ', icon: Icons.check_rounded, onPressed: _save),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifications.dart';
import '../core/settings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'dashboard_screen.dart';
import 'debts_screen.dart';
import 'expense_form.dart';
import 'expenses_screen.dart';
import 'person_forms.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askName());
  }

  /// First run: ask the owner's name (shown as sender on PDF statements).
  Future<void> _askName() async {
    final prefs = await SharedPreferences.getInstance();
    if (AppSettings.ownerName.value.isNotEmpty || prefs.getBool('asked_owner') == true) {
      await NotificationService.I.requestAllOnce();
      return;
    }
    await prefs.setBool('asked_owner', true);
    if (!mounted) return;
    final p = Pal.of(context);
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (d) => Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Center(child: BrandMark(size: 58)),
            const SizedBox(height: 14),
            Text('أهلاً بك في كاش بوك',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 20, color: p.text)),
            const SizedBox(height: 8),
            Text('اكتب اسمك أو اسم محلك ليظهر كمُرسِل في كشوف الحساب التي ترسلها لزبائنك',
                textAlign: TextAlign.center, style: TextStyle(color: p.dim, height: 1.6, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: c,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'مثلاً: أيهم الغزاوي', prefixIcon: Icon(Icons.badge_rounded)),
            ),
            const SizedBox(height: 16),
            GoldButton(label: 'حفظ', icon: Icons.check_rounded, onPressed: () => Navigator.pop(d, c.text.trim())),
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: Text('لاحقاً', style: TextStyle(color: p.faint)),
            ),
          ]),
        ),
      ),
    );
    if (name != null && name.isNotEmpty) await AppSettings.setOwnerName(name);
    // Then ask for notifications + exact reminders once, so they work right away.
    await NotificationService.I.requestAllOnce();
  }

  void go(int i) => setState(() => _tab = i);

  Future<void> _quickAdd() async {
    HapticFeedback.mediumImpact();
    final p = Pal.of(context);
    await showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetHeader('إضافة سريعة'),
            _QuickTile(
              icon: Icons.person_add_alt_1_rounded,
              color: p.blue,
              title: 'شخص جديد',
              subtitle: 'أضف اسم ورقم شخص جديد',
              onTap: () {
                Navigator.pop(c);
                addPersonFlow(context);
              },
            ),
            const SizedBox(height: 12),
            _QuickTile(
              icon: Icons.request_quote_rounded,
              color: p.green,
              title: 'دين جديد',
              subtitle: 'اختر شخصاً من قائمتك وسجّل المبلغ',
              onTap: () {
                Navigator.pop(c);
                newDebtFlow(context);
              },
            ),
            const SizedBox(height: 12),
            _QuickTile(
              icon: Icons.event_repeat_rounded,
              color: p.gold,
              title: 'مصروف دوري',
              subtitle: 'إيجار، فواتير، اشتراكات… مع تذكير قبل الموعد',
              onTap: () {
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseForm()));
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onGo: go),
      DebtsScreen(active: _tab == 1),
      const ExpensesScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: AppBackground(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: _NavBar(index: _tab, onTap: go, onAdd: _quickAdd),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  const _NavBar({required this.index, required this.onTap, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget item(int i, IconData icon, IconData active, String label) {
      final sel = i == index;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap(i);
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? p.gold.withValues(alpha: 0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(sel ? active : icon, color: sel ? p.gold : p.faint, size: 23),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? p.gold : p.faint,
                )),
          ]),
        ),
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: p.dark ? const Color(0xF2101C19) : const Color(0xF7FFFFFF),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: p.line),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: p.dark ? 0.45 : 0.10), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(children: [
          item(0, Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'الرئيسية'),
          item(1, Icons.people_alt_outlined, Icons.people_alt_rounded, 'الديون'),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [p.gold, p.goldDeep], begin: Alignment.topRight, end: Alignment.bottomLeft),
                boxShadow: [BoxShadow(color: p.gold.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.add_rounded, color: Color(0xFF14110A), size: 30),
            ),
          ),
          item(2, Icons.event_note_outlined, Icons.event_note_rounded, 'المصاريف'),
          item(3, Icons.tune_outlined, Icons.tune_rounded, 'الإعدادات'),
        ]),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickTile(
      {required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Surface(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: p.dim, fontSize: 12.5)),
          ]),
        ),
        Icon(Icons.chevron_left_rounded, color: p.faint),
      ]),
    );
  }
}

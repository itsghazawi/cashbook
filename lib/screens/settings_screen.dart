import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_lock.dart';
import '../core/backup.dart';
import '../core/format.dart';
import '../core/license.dart';
import '../core/models.dart';
import '../core/notifications.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../main.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'app_lock_screen.dart';

/// Asks once for the owner's name shown on PDF statements.
Future<String?> ensureOwnerName(BuildContext context, {bool force = false}) async {
  final saved = AppSettings.ownerName.value;
  if (saved.isNotEmpty && !force) return saved;
  if (!context.mounted) return null;
  final c = TextEditingController(text: saved);
  final r = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('اسمك في كشوف الحساب'),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'مثلاً: أيهم الغزاوي / محل النور'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('حفظ')),
      ],
    ),
  );
  if (r == null || r.isEmpty) return null;
  await AppSettings.setOwnerName(r);
  return r;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _device = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final d = await License.I.deviceCode();
    if (!mounted) return;
    setState(() => _device = d);
  }

  Future<void> _editRate() async {
    final c = TextEditingController(text: AppStore.I.lastRate > 0 ? fmtNum(AppStore.I.lastRate) : '');
    final r = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('سعر صرف الدولار'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [ThousandsFormatter()],
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(suffixText: 'ل.س / \$1'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(d, parseNum(c.text)), child: const Text('حفظ')),
        ],
      ),
    );
    if (r != null && r > 0) {
      await AppStore.I.setLastRate(r);
      setState(() {});
    }
  }

  Future<void> _restoreSnapshot() async {
    final snaps = await AppStore.I.listSnapshots();
    if (!mounted) return;
    if (snaps.isEmpty) {
      toast(context, 'لا توجد نسخ تلقائية بعد');
      return;
    }
    final f = await showModalBottomSheet<File>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const SheetHeader('النسخ التلقائية على الجهاز', subtitle: 'يحتفظ التطبيق بآخر 10 نسخ يومية تلقائياً'),
            ...snaps.map((s) {
              final n = s.uri.pathSegments.last.replaceAll('.json', '');
              final dt = DateTime.tryParse(
                  '${n.substring(0, 4)}-${n.substring(4, 6)}-${n.substring(6, 8)}T${n.substring(9, 11)}:${n.substring(11, 13)}');
              return ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(dt == null ? n : fmtDateTime(dt)),
                onTap: () => Navigator.pop(c, s),
              );
            }),
          ],
        ),
      ),
    );
    if (f == null || !mounted) return;
    if (!await confirm(context, title: 'استعادة النسخة؟', message: 'ستُستبدل البيانات الحالية بهذه النسخة.', ok: 'استعادة')) {
      return;
    }
    final err = await AppStore.I.importBackup(await f.readAsString());
    if (mounted) toast(context, err ?? 'تمت الاستعادة بنجاح', error: err != null);
  }

  Future<void> _restoreDrive() async {
    final b = BackupService.I;
    try {
      final list = await b.listDriveBackups();
      if (!mounted) return;
      if (list.isEmpty) {
        toast(context, 'لا توجد نسخ على Google Drive');
        return;
      }
      final f = await showModalBottomSheet<DriveFile>(
        context: context,
        builder: (c) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              const SheetHeader('نسخ Google Drive'),
              ...list.map((x) => ListTile(
                    leading: const Icon(Icons.cloud_done_rounded),
                    title: Text(x.modified == null ? x.name : fmtDateTime(x.modified!)),
                    subtitle: x.size == null ? null : Text('${(x.size! / 1024).toStringAsFixed(1)} KB'),
                    onTap: () => Navigator.pop(c, x),
                  )),
            ],
          ),
        ),
      );
      if (f == null || !mounted) return;
      if (!await confirm(context, title: 'استعادة من Drive؟', message: 'ستُستبدل البيانات الحالية بهذه النسخة.', ok: 'استعادة')) {
        return;
      }
      final err = await b.restoreFromDrive(f);
      if (mounted) toast(context, err ?? 'تمت الاستعادة بنجاح', error: err != null);
    } catch (_) {
      if (mounted) toast(context, 'تعذّر الوصول إلى Google Drive', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([AppLock.enabled, AppLock.biometric, BackupService.I, AppStore.I, themeMode, AppSettings.ownerName, AppSettings.reminders]),
      builder: (context, _) {
        final b = BackupService.I;
        return SafeArea(
          bottom: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Text('الإعدادات',
                  style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 26, color: p.text)),
            ),
            Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(18, 0, 18, navClearance(context) + 10),
            children: [
              const SectionHeader('عام'),
              _Group(children: [
                _Item(
                  icon: Icons.badge_rounded,
                  title: 'اسمك في كشوف الحساب',
                  value: AppSettings.ownerName.value.isEmpty ? 'غير محدد' : AppSettings.ownerName.value,
                  onTap: () => ensureOwnerName(context, force: true),
                ),
                _Item(
                  icon: Icons.currency_exchange_rounded,
                  title: 'سعر صرف الدولار الافتراضي',
                  value: AppStore.I.lastRate > 0 ? '${fmtNum(AppStore.I.lastRate)} ل.س' : 'غير محدد',
                  onTap: _editRate,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Segmented<ThemeMode>(
                    value: themeMode.value,
                    onChanged: setTheme,
                    items: const [
                      (ThemeMode.system, 'تلقائي', null),
                      (ThemeMode.dark, 'داكن', null),
                      (ThemeMode.light, 'فاتح', null),
                    ],
                  ),
                ),
              ]),
              const SectionHeader('قفل التطبيق'),
              _Group(children: [
                _SwitchItem(
                  icon: Icons.lock_rounded,
                  title: 'قفل بالرمز السري',
                  subtitle: 'يطلب رمزاً من 4 أرقام عند فتح التطبيق',
                  value: AppLock.enabled.value,
                  onChanged: (v) async {
                    if (v) {
                      await Navigator.push<bool>(
                          context, MaterialPageRoute(builder: (_) => const AppLockScreen(setMode: true)));
                    } else {
                      await AppLock.disable();
                    }
                  },
                ),
                if (AppLock.enabled.value) ...[
                  _SwitchItem(
                    icon: Platform.isIOS ? Icons.face_rounded : Icons.fingerprint_rounded,
                    title: 'الفتح بـ${AppLock.bioName}',
                    subtitle: Platform.isIOS ? 'افتح التطبيق بوجهك بدل الرمز' : 'افتح التطبيق ببصمة إصبعك بدل الرمز',
                    value: AppLock.biometric.value,
                    onChanged: (v) async {
                      if (v) {
                        if (!await AppLock.bioAvailable()) {
                          if (context.mounted) {
                            toast(context, 'فعّل ${AppLock.bioName} من إعدادات الهاتف أولاً', error: true);
                          }
                          return;
                        }
                        if (!await AppLock.bioUnlock(reason: 'تأكيد تفعيل ${AppLock.bioName}')) return;
                      }
                      await AppLock.setBiometric(v);
                    },
                  ),
                  _Item(
                    icon: Icons.password_rounded,
                    title: 'تغيير الرمز السري',
                    value: 'أدخل الرمز الجديد مباشرة',
                    onTap: () async {
                      final ok = await Navigator.push<bool>(
                          context, MaterialPageRoute(builder: (_) => const AppLockScreen(setMode: true)));
                      if (ok == true && context.mounted) toast(context, 'تم تغيير الرمز السري ✓');
                    },
                  ),
                ],
              ]),
              const SectionHeader('النسخة اليومية على الجهاز'),
              _Group(children: [
                _Item(
                  icon: Icons.schedule_rounded,
                  title: 'نسخة تلقائية كل يوم الساعة 12 بالليل',
                  value: b.lastDaily == null ? 'لم تُؤخذ أي نسخة بعد' : 'آخر نسخة: ${fmtDateTime(b.lastDaily!)}',
                  valueColor: b.lastDaily == null ? p.faint : p.green,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.gold.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.gold.withValues(alpha: 0.22)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.folder_rounded, size: 16, color: p.gold),
                        const SizedBox(width: 6),
                        Text('مسار النسخة', style: TextStyle(color: p.gold, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ]),
                      const SizedBox(height: 6),
                      Text(b.dailyPlace, style: TextStyle(color: p.text, fontSize: 12.5, height: 1.5)),
                      if (b.dailyPath != null) ...[
                        const SizedBox(height: 4),
                        SelectableText(b.dailyPath!,
                            textDirection: TextDirection.ltr, style: TextStyle(color: p.faint, fontSize: 11)),
                      ],
                    ]),
                  ),
                ),
                _Item(
                  icon: Icons.backup_rounded,
                  title: 'خذ نسخة الآن',
                  value: 'تحديث ملف النسخة اليومية فوراً',
                  onTap: () async {
                    final ok = await b.writeDaily();
                    if (context.mounted) toast(context, ok ? 'تم حفظ النسخة ✓' : 'تعذّر الحفظ', error: !ok);
                  },
                ),
                _Item(
                  icon: Icons.settings_backup_restore_rounded,
                  title: 'استعادة من النسخة اليومية',
                  value: 'ترجيع البيانات من ملف النسخة اليومية',
                  onTap: () async {
                    if (!await confirm(context,
                        title: 'استعادة النسخة اليومية؟', message: 'ستُستبدل البيانات الحالية بمحتوى النسخة.', ok: 'متابعة')) {
                      return;
                    }
                    final err = await b.restoreDaily();
                    if (context.mounted) toast(context, err ?? 'تمت الاستعادة بنجاح ✓', error: err != null);
                  },
                ),
              ]),
              const SectionHeader('Google Drive'),
              _Group(children: [
                _Item(
                  icon: Icons.add_to_drive_rounded,
                  title: 'نسخ إلى Google Drive',
                  value: 'من القائمة اختر تطبيق Drive واحفظ الملف',
                  onTap: () async {
                    try {
                      await b.shareToDrive();
                    } catch (_) {
                      if (context.mounted) toast(context, 'تعذّر فتح المشاركة', error: true);
                    }
                  },
                ),
                _Item(
                  icon: Icons.cloud_download_rounded,
                  title: 'استيراد من Google Drive',
                  value: 'افتح Drive من نافذة الملفات واختر ملف النسخة',
                  onTap: () async {
                    if (!await confirm(context,
                        title: 'استعادة نسخة؟', message: 'ستُستبدل البيانات الحالية بمحتوى النسخة.', ok: 'متابعة')) {
                      return;
                    }
                    final err = await b.restoreFromDevice();
                    if (err == '' || !context.mounted) return;
                    toast(context, err ?? 'تمت الاستعادة بنجاح ✓', error: err != null);
                  },
                ),
              ]),
              const SectionHeader('نسخ يدوي على الهاتف'),
              _Group(children: [
                _Item(
                  icon: Icons.save_alt_rounded,
                  title: 'حفظ نسخة على الهاتف',
                  value: 'اختر مكان الحفظ (التنزيلات مثلاً)',
                  onTap: () async {
                    try {
                      final ok = await b.saveToDevice();
                      if (ok && context.mounted) toast(context, 'تم حفظ النسخة ✓');
                    } catch (_) {
                      if (context.mounted) toast(context, 'تعذّر الحفظ', error: true);
                    }
                  },
                ),
                _Item(
                  icon: Icons.ios_share_rounded,
                  title: 'مشاركة النسخة',
                  value: 'أرسلها لنفسك على واتساب أو تيليجرام',
                  onTap: b.shareBackup,
                ),
                _Item(
                  icon: Icons.restore_page_rounded,
                  title: 'استعادة من ملف',
                  value: 'اختر ملف نسخة احتياطية (.json)',
                  onTap: () async {
                    if (!await confirm(context,
                        title: 'استعادة من ملف؟', message: 'ستُستبدل البيانات الحالية بمحتوى الملف.', ok: 'متابعة')) {
                      return;
                    }
                    final err = await b.restoreFromDevice();
                    if (err == '' || !context.mounted) return;
                    toast(context, err ?? 'تمت الاستعادة بنجاح ✓', error: err != null);
                  },
                ),
                _Item(
                  icon: Icons.history_rounded,
                  title: 'النسخ التلقائية',
                  value: 'آخر 10 نسخ يومية محفوظة داخل التطبيق',
                  onTap: _restoreSnapshot,
                ),
              ]),
              const SectionHeader('التذكير بالمصاريف'),
              _Group(children: [
                for (final m in AppSettings.options)
                  _SwitchItem(
                    icon: m == 0 ? Icons.notifications_active_rounded : Icons.alarm_rounded,
                    title: Remind.label(m),
                    subtitle: m == 0 ? 'إشعار في وقت الدفع نفسه' : 'إشعار ${Remind.label(m)} من موعد الدفع',
                    value: AppSettings.reminders.value.contains(m),
                    onChanged: (v) async {
                      await AppSettings.setReminder(m, v);
                      await NotificationService.I.rescheduleAll(AppStore.I.expenses);
                    },
                  ),
                _Item(
                  icon: Icons.notification_add_rounded,
                  title: 'إرسال إشعار تجريبي',
                  value: 'للتأكد أن التذكيرات تصلك',
                  onTap: () => NotificationService.I.showTest(),
                ),
              ]),
              const SectionHeader('الترخيص'),
              _Group(children: [
                _Item(
                  icon: Icons.verified_rounded,
                  title: 'حالة النسخة',
                  value: 'مفعّلة',
                  valueColor: p.green,
                ),
                _Item(
                  icon: Icons.fingerprint_rounded,
                  title: 'كود الجهاز',
                  value: _device,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _device));
                    toast(context, 'تم نسخ كود الجهاز');
                  },
                ),
              ]),
              const SectionHeader('حول التطبيق'),
              const _AboutCard(),
            ],
          ),
            ),
          ]),
        );
      },
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget link(IconData icon, String label, Color c, String url) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.14)),
                  child: Icon(icon, color: c, size: 20),
                ),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(color: p.dim, fontSize: 11.5)),
              ]),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: p.hero, begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border.all(color: const Color(0xFFDDB872).withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const BrandMark(size: 60),
        const SizedBox(height: 12),
        const Text('كاش بوك',
            style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
        Text('الإصدار $appVersion', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
        const SizedBox(height: 14),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        const SizedBox(height: 14),
        Text('صُمّم وطُوّر بواسطة', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12.5)),
        const SizedBox(height: 4),
        const Text('أيهم الغزاوي',
            style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, fontSize: 20, color: Color(0xFFEBCB8B))),
        Text('مصمم جرافيك ومطوّر ويب وتطبيقات',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          link(Icons.chat_rounded, 'واتساب', const Color(0xFF25D366), 'https://wa.me/${License.devWhatsApp}'),
          link(Icons.send_rounded, 'تيليجرام', const Color(0xFF2AABEE), 'https://t.me/${License.devTelegram}'),
          link(Icons.mail_rounded, 'البريد', const Color(0xFFEBCB8B), 'mailto:${License.devEmail}'),
          link(Icons.language_rounded, 'الموقع', const Color(0xFF9FD3FF), 'https://${License.devSite}'),
        ]),
      ]),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) items.add(Divider(height: 1, indent: 58, color: p.line));
    }
    return Surface(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: items));
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _Item({required this.icon, required this.title, required this.value, this.valueColor, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: p.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: p.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: p.text, fontWeight: FontWeight.w600, fontSize: 14)),
              if (value.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: valueColor ?? p.dim, fontSize: 12)),
              ],
            ]),
          ),
          trailing ?? (onTap != null ? Icon(Icons.chevron_left_rounded, color: p.faint) : const SizedBox.shrink()),
        ]),
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchItem(
      {required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _Item(
        icon: icon,
        title: title,
        value: subtitle,
        trailing: Switch(value: value, onChanged: onChanged),
      );
}


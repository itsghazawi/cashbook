import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/backup.dart';
import '../core/license.dart';
import '../core/notifications.dart';
import '../core/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'home_shell.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _code = '';
  final _act = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    License.I.deviceCode().then((c) => setState(() => _code = c));
  }

  Future<void> _whatsapp() async {
    final msg = 'مرحباً أستاذ أيهم 👋\nأرغب بتفعيل تطبيق كاش بوك.\n\nكود الجهاز:\n$_code';
    final uri = Uri.parse('https://wa.me/${License.devWhatsApp}?text=${Uri.encodeComponent(msg)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) toast(context, 'تعذّر فتح واتساب', error: true);
    }
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _act.text = d!.text!.trim());
  }

  Future<void> _activate() async {
    if (_act.text.trim().isEmpty) {
      setState(() => _error = 'الصق كود التفعيل أولاً');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await License.I.activate(_act.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'كود التفعيل غير صحيح لهذا الجهاز';
      });
      HapticFeedback.heavyImpact();
      return;
    }
    await AppStore.I.load();
    await BackupService.I.init();
    await NotificationService.I.rescheduleAll(AppStore.I.expenses);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    await showDialog(
      context: context,
      builder: (c) => const _SuccessDialog(),
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
            children: [
              const FadeIn(child: Center(child: BrandMark(size: 78))),
              const SizedBox(height: 22),
              FadeIn(
                index: 1,
                child: Column(children: [
                  Text('كاش بوك',
                      style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 30, color: p.text)),
                  const SizedBox(height: 8),
                  Text('هذه النسخة تحتاج إلى تفعيل',
                      style: TextStyle(color: p.dim, fontSize: 15, fontWeight: FontWeight.w300)),
                ]),
              ),
              const SizedBox(height: 30),
              FadeIn(
                index: 2,
                child: Surface(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Step(n: '١', text: 'انسخ كود جهازك أو أرسله مباشرة عبر واتساب'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(colors: [
                          p.gold.withValues(alpha: 0.14),
                          p.gold.withValues(alpha: 0.04),
                        ]),
                        border: Border.all(color: p.gold.withValues(alpha: 0.35)),
                      ),
                      child: Column(children: [
                        Text('كود الجهاز', style: TextStyle(color: p.dim, fontSize: 12.5)),
                        const SizedBox(height: 8),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: FittedBox(
                            child: SelectableText(
                              _code.isEmpty ? '····-····-····-····' : _code,
                              style: TextStyle(
                                fontFamily: kHead,
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                                letterSpacing: 2.5,
                                color: p.gold,
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: GhostButton(
                          label: 'نسخ الكود',
                          icon: Icons.copy_rounded,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _code));
                            toast(context, 'تم نسخ كود الجهاز');
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    GoldButton(
                      label: 'تواصل عبر واتساب  ${License.devWhatsAppLocal}',
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      textColor: Colors.white,
                      onPressed: _code.isEmpty ? null : _whatsapp,
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              FadeIn(
                index: 3,
                child: Surface(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Step(n: '٢', text: 'الصق كود التفعيل الذي يصلك من المطوّر'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _act,
                      minLines: 2,
                      maxLines: 4,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontFamily: kBody, fontSize: 13.5, letterSpacing: 0.5),
                      decoration: InputDecoration(
                        hintText: 'كود التفعيل',
                        errorText: _error,
                        suffixIcon: IconButton(
                          tooltip: 'لصق',
                          icon: Icon(Icons.content_paste_rounded, color: p.gold),
                          onPressed: _paste,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GoldButton(
                      label: 'تفعيل التطبيق',
                      icon: Icons.verified_rounded,
                      loading: _busy,
                      onPressed: _activate,
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Column(children: [
                  Text('تصميم وتطوير', style: TextStyle(color: p.faint, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text('أيهم الغزاوي',
                      style: TextStyle(fontFamily: kHead, color: p.gold, fontWeight: FontWeight.w600, fontSize: 15)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(children: [
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: p.gold.withValues(alpha: 0.16)),
        child: Text(n, style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, color: p.gold)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(color: p.text, fontWeight: FontWeight.w500, height: 1.5))),
    ]);
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.green.withValues(alpha: 0.15)),
              child: Icon(Icons.verified_rounded, color: p.green, size: 48),
            ),
          ),
          const SizedBox(height: 18),
          Text('تم التفعيل بنجاح',
              style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 21, color: p.text)),
          const SizedBox(height: 8),
          Text('أهلاً بك في كاش بوك، استمتع بإدارة ديونك ومصاريفك',
              textAlign: TextAlign.center, style: TextStyle(color: p.dim, height: 1.6)),
          const SizedBox(height: 22),
          GoldButton(label: 'ابدأ الآن', onPressed: () => Navigator.pop(context)),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_lock.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Unlock with PIN / biometrics, or set a new PIN ([setMode]).
/// Pops `true` on success (unless [onUnlocked] is given).
class AppLockScreen extends StatefulWidget {
  final bool setMode;
  final VoidCallback? onUnlocked;
  const AppLockScreen({super.key, this.setMode = false, this.onUnlocked});
  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _entry = '';
  String? _first;
  String? _msg;
  bool _shake = false;

  bool get _bioKey => !widget.setMode && AppLock.biometric.value;

  @override
  void initState() {
    super.initState();
    if (_bioKey) WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  Future<void> _bio() async {
    if (await AppLock.bioUnlock() && mounted) _done();
  }

  void _done() {
    HapticFeedback.mediumImpact();
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else {
      Navigator.pop(context, true);
    }
  }

  void _fail(String m) {
    HapticFeedback.heavyImpact();
    setState(() {
      _msg = m;
      _entry = '';
      _shake = !_shake;
    });
  }

  Future<void> _tap(String d) async {
    HapticFeedback.selectionClick();
    if (d == 'B') return _bio();
    if (d == '<') {
      if (_entry.isNotEmpty) setState(() => _entry = _entry.substring(0, _entry.length - 1));
      return;
    }
    if (_entry.length >= 4) return;
    setState(() {
      _entry += d;
      _msg = null;
    });
    if (_entry.length < 4) return;
    if (!widget.setMode) {
      (await AppLock.check(_entry)) ? _done() : _fail('رمز غير صحيح');
    } else if (_first == null) {
      setState(() {
        _first = _entry;
        _entry = '';
      });
    } else if (_first == _entry) {
      await AppLock.setPin(_entry);
      _done();
    } else {
      setState(() => _first = null);
      _fail('الرمزان غير متطابقين، أعد المحاولة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final title = !widget.setMode
        ? 'أدخل الرمز السري'
        : (_first == null ? 'أدخل رمزاً سرياً من 4 أرقام' : 'أعد إدخال الرمز للتأكيد');
    Widget key(String d) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: AspectRatio(
              aspectRatio: 1.55,
              child: Material(
                color: d.isEmpty ? Colors.transparent : p.card,
                borderRadius: BorderRadius.circular(20),
                child: d.isEmpty
                    ? null
                    : InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _tap(d),
                        child: Center(
                          child: d == 'B'
                              ? Icon(Theme.of(context).platform == TargetPlatform.iOS ? Icons.face_rounded : Icons.fingerprint_rounded,
                                  color: p.gold, size: 30)
                              : d == '<'
                                  ? Icon(Icons.backspace_outlined, color: p.dim)
                                  : Text(d,
                                      style: TextStyle(
                                          fontFamily: kHead, fontSize: 26, fontWeight: FontWeight.w600, color: p.text)),
                        ),
                      ),
              ),
            ),
          ),
        );
    return PopScope(
      canPop: widget.setMode,
      child: Scaffold(
        appBar: widget.setMode ? AppBar(title: const Text('الرمز السري')) : null,
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                const Spacer(),
                const BrandMark(size: 70),
                const SizedBox(height: 16),
                Text('كاش بوك', style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w800, fontSize: 26, color: p.text)),
                const SizedBox(height: 6),
                Text(title, style: TextStyle(color: p.dim)),
                const SizedBox(height: 24),
                TweenAnimationBuilder<double>(
                  key: ValueKey(_shake),
                  tween: Tween(begin: 1, end: 0),
                  duration: const Duration(milliseconds: 400),
                  builder: (_, v, child) => Transform.translate(
                    offset: Offset(12 * v * (((v * 10).floor() % 2 == 0) ? 1 : -1), 0),
                    child: child,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final on = i < _entry.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 9),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: on ? p.gold : Colors.transparent,
                          border: Border.all(color: on ? p.gold : p.faint, width: 1.6),
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(height: 34, child: Center(child: Text(_msg ?? '', style: TextStyle(color: p.rose, fontSize: 13)))),
                const Spacer(),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(children: [
                    for (final row in [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      [_bioKey ? 'B' : '', '0', '<'],
                    ])
                      Row(children: row.map(key).toList()),
                  ]),
                ),
                const SizedBox(height: 18),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

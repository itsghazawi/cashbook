import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import 'theme.dart';

/// No stretch / bounce when pulling past the top: headers stay put.
class FixedScrollBehavior extends MaterialScrollBehavior {
  const FixedScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// Space a bottom sheet / page needs so nothing sits under the Android
/// navigation buttons (or the keyboard).
double bottomGap(BuildContext context) {
  final m = MediaQuery.of(context);
  final a = m.viewInsets.bottom, b = m.viewPadding.bottom;
  return a > b ? a : b;
}

/// Bottom padding for tab pages so the last item clears the floating nav bar.
double navClearance(BuildContext context) => 118 + MediaQuery.of(context).viewPadding.bottom;

/// Page background with a soft gold/emerald glow.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Stack(children: [
      Positioned.fill(child: ColoredBox(color: p.bg)),
      Positioned(
        top: -160,
        left: -120,
        child: _Glow(color: p.green.withValues(alpha: p.dark ? 0.10 : 0.10), size: 420),
      ),
      Positioned(
        top: 80,
        right: -160,
        child: _Glow(color: p.gold.withValues(alpha: p.dark ? 0.08 : 0.10), size: 380),
      ),
      Positioned.fill(child: child),
    ]);
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
          ),
        ),
      );
}

/// Elevated card with hairline border.
class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;

  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.onLongPress,
    this.radius = 22,
    this.color,
    this.gradient,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? p.card) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? p.line),
        boxShadow: p.dark
            ? null
            : [BoxShadow(color: const Color(0xFF10201B).withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final Color? textColor;
  final bool expand;

  const GoldButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.color,
    this.textColor,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = color;
    final grad = c == null
        ? LinearGradient(colors: [p.gold, p.goldDeep], begin: Alignment.topRight, end: Alignment.bottomLeft)
        : LinearGradient(colors: [c, Color.lerp(c, Colors.black, 0.18)!]);
    final fg = textColor ?? const Color(0xFF14110A);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        else if (icon != null)
          Icon(icon, color: fg, size: 21),
        if (icon != null || loading) const SizedBox(width: 10),
        Text(label, style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, fontSize: 15.5, color: fg)),
      ],
    );
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: grad,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: (c ?? p.gold).withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: loading
                ? null
                : onPressed == null
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onPressed!();
                      },
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: content),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  const GhostButton({super.key, required this.label, this.icon, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = color ?? p.text;
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20, color: c),
        label: Text(label, style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w600, color: c)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: c.withValues(alpha: 0.25)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: p.gold, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, fontSize: 17, color: p.text)),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: TextStyle(color: p.gold, fontWeight: FontWeight.w600, fontSize: 13.5)),
          ),
      ]),
    );
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? tone;
  const Avatar(this.name, {super.key, this.size = 46, this.tone});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final t = name.trim();
    final letter = t.isEmpty ? '؟' : t.characters.first;
    final c = tone ?? p.gold;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.28), c.withValues(alpha: 0.10)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(letter,
          style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, fontSize: size * 0.42, color: c, height: 1.2)),
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Tag(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [p.gold.withValues(alpha: 0.22), p.gold.withValues(alpha: 0.02)]),
          ),
          child: Icon(icon, size: 40, color: p.gold),
        ),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, fontSize: 18, color: p.text)),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: p.dim, height: 1.6, fontWeight: FontWeight.w300)),
        if (action != null) ...[const SizedBox(height: 22), action!],
      ]),
    );
  }
}

/// Fades + slides children in on first build.
class FadeIn extends StatefulWidget {
  final Widget child;
  final int index;
  const FadeIn({super.key, required this.child, this.index = 0});
  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 40 * widget.index.clamp(0, 10)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a),
        child: widget.child,
      ),
    );
  }
}

/// App mark: deep emerald tile, gold border, Arabic "ك".
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [BoxShadow(color: const Color(0xFFDDB872).withValues(alpha: 0.22), blurRadius: size * 0.4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset('assets/brand/icon.png', width: size, height: size, filterQuality: FilterQuality.high),
      ),
    );
  }
}

/// Money text: number big, currency small.
class MoneyText extends StatelessWidget {
  final double value;
  final String currency;
  final double size;
  final Color? color;
  final FontWeight weight;
  const MoneyText(this.value, this.currency,
      {super.key, this.size = 18, this.color, this.weight = FontWeight.w700});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = color ?? p.text;
    final n = fmtNum(value.abs(), decimals: currency == Cur.usd);
    final sym = Cur.symbol(currency);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: n, style: TextStyle(fontFamily: kHead, fontWeight: weight, fontSize: size, color: c)),
          WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: SizedBox(width: size * 0.28)),
          TextSpan(
              text: sym,
              style: TextStyle(fontFamily: kBody, fontWeight: FontWeight.w500, fontSize: size * 0.58, color: c.withValues(alpha: 0.75))),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

void toast(BuildContext context, String msg, {bool error = false}) {
  final p = Pal.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: error ? p.rose : p.green, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
    ));
}

Future<bool> confirm(BuildContext context,
    {required String title, required String message, String ok = 'تأكيد', bool danger = false}) async {
  final p = Pal.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message, style: TextStyle(color: p.dim, height: 1.6)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء', style: TextStyle(color: p.dim))),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok, style: TextStyle(color: danger ? p.rose : p.gold, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Grab handle + title for bottom sheets.
class SheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SheetHeader(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(children: [
      const SizedBox(height: 10),
      Container(width: 44, height: 5, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 18),
      Text(title, style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, fontSize: 19, color: p.text)),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: p.dim, fontSize: 13)),
      ],
      const SizedBox(height: 18),
    ]);
  }
}

/// Segmented selector used for currency, direction, repeat…
class Segmented<T> extends StatelessWidget {
  final List<(T, String, Color?)> items;
  final T value;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.items, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: p.dark ? const Color(0xFF0E1A17) : const Color(0xFFEDE8DC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: items.map((it) {
          final sel = it.$1 == value;
          final c = it.$3 ?? p.gold;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(it.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? c.withValues(alpha: p.dark ? 0.18 : 0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? c.withValues(alpha: 0.5) : Colors.transparent),
                ),
                alignment: Alignment.center,
                child: Text(it.$2,
                    style: TextStyle(
                      fontFamily: kHead,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                      color: sel ? c : p.dim,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Big animated ✔ that pops in the middle of the screen, then fades away.
Future<void> showDoneTick(BuildContext context, String label) async {
  final p = Pal.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  var open = true;
  Future.delayed(const Duration(milliseconds: 1300), () {
    if (open && nav.mounted) nav.pop();
  });
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'done',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 170,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
          decoration: BoxDecoration(
            color: p.bg2,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: p.green.withValues(alpha: 0.4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.green),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
              ),
            ),
            const SizedBox(height: 14),
            Text(label, style: TextStyle(fontFamily: kHead, fontWeight: FontWeight.w700, fontSize: 17, color: p.text)),
          ]),
        ),
      ),
    ),
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), child: child),
    ),
  );
  open = false;
}

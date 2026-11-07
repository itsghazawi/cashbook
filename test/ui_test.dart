import 'package:cashbook/screens/dashboard_screen.dart';
import 'package:cashbook/screens/debts_screen.dart';
import 'package:cashbook/screens/expenses_screen.dart';
import 'package:cashbook/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap(Widget w) => MaterialApp(
      theme: buildTheme(Pal.darkPal),
      home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: w)),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('tabs render', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    t.view.padding = const FakeViewPadding(bottom: 144);
    t.view.viewPadding = const FakeViewPadding(bottom: 144);
    await t.pumpWidget(wrap(DashboardScreen(onGo: (_) {})));
    await t.pump(const Duration(seconds: 2));
    await t.tap(find.text('علي للناس'));
    await t.pumpWidget(wrap(const DebtsScreen()));
    await t.pump(const Duration(seconds: 2));
    await t.pumpWidget(wrap(const ExpensesScreen()));
    await t.pump(const Duration(seconds: 2));
  });
}

import 'dart:io';

import 'package:cashbook/core/rate_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses sp-today sell price (old lira)', () {
    final html = File('test/fixtures/sp_today_usd.html').readAsStringSync();
    expect(RateService.parse(html), 14425);
  });
}

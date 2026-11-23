import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kardkhana/call_break/offline_call_break.dart';

void main() {
  testWidgets('offline Call Break gives each CPU 1.5 seconds', (tester) async {
    final table = OfflineCallBreak(random: Random(19));
    try {
      if (table.view['turn'] == 0) table.send('bid', {'bid': 3});
      final cpu = table.view['turn'] as int;
      expect(cpu, isNot(0));

      Object? bid() => (table.view['players'] as List)[cpu]['bid'];
      await tester.pump(const Duration(milliseconds: 1499));
      expect(bid(), isNull);

      await tester.pump(const Duration(milliseconds: 1));
      expect(bid(), isNotNull);
    } finally {
      table.dispose();
    }
  });
}

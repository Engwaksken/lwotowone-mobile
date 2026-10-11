import 'package:flutter_test/flutter_test.dart';
import 'package:lwotowone_mobile/services/earnings.dart';

void main() {
  final records = [
    {
      'enterprise_id': 1,
      'type': 'income',
      'amount': '1000.00',
      'occurred_on': '2026-10-01',
    },
    {
      'enterprise_id': 1,
      'type': 'expense',
      'amount': 300,
      'occurred_on': '2026-10-04',
    },
    {
      'enterprise_id': 1,
      'type': 'income',
      'amount': 9000,
      'occurred_on': '2026-09-30',
    },
    {
      'enterprise_id': 2,
      'type': 'income',
      'amount': 5000,
      'occurred_on': '2026-10-01',
    },
    {
      'enterprise_id': 1,
      'type': 'income',
      'amount': 8000,
      'occurred_on': '2026-10-05',
    },
  ];
  test(
    'Month totals match the selected enterprise and exclude future records',
    () {
      final result = Earnings.filter(
        records,
        period: EarningsPeriod.month,
        enterpriseId: '1',
        today: DateTime(2026, 10, 4),
      );
      expect(result.income, 1000);
      expect(result.expense, 300);
      expect(result.net, 700);
      expect(result.transactions.length, 2);
    },
  );
  test('Week begins on Monday and custom dates include both boundaries', () {
    final week = Earnings.filter(
      records,
      period: EarningsPeriod.week,
      enterpriseId: '1',
      today: DateTime(2026, 10, 4),
    );
    expect(week.income, 10000);
    final range = Earnings.filter(
      records,
      period: EarningsPeriod.custom,
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 4),
      enterpriseId: '1',
    );
    expect(range.transactions.length, 2);
  });
  test('Invalid custom range fails explicitly', () {
    expect(
      () => Earnings.filter(records, period: EarningsPeriod.custom),
      throwsArgumentError,
    );
    expect(
      () => Earnings.filter(
        records,
        period: EarningsPeriod.custom,
        from: DateTime(2026, 10, 4),
        to: DateTime(2026, 10, 1),
      ),
      throwsArgumentError,
    );
  });
}

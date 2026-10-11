enum EarningsPeriod {
  all('All time'),
  week('This week'),
  month('This month'),
  year('This year'),
  custom('Custom dates');

  const EarningsPeriod(this.label);
  final String label;
}

class Earnings {
  final List<Map<String, dynamic>> transactions;
  Earnings._(this.transactions);
  factory Earnings.filter(
    List<Map<String, dynamic>> records, {
    EarningsPeriod period = EarningsPeriod.all,
    String? enterpriseId,
    DateTime? today,
    DateTime? from,
    DateTime? to,
  }) {
    final now = today ?? DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    DateTime? start, end;
    switch (period) {
      case EarningsPeriod.week:
        start = date.subtract(Duration(days: date.weekday - 1));
        end = date;
      case EarningsPeriod.month:
        start = DateTime(date.year, date.month);
        end = date;
      case EarningsPeriod.year:
        start = DateTime(date.year);
        end = date;
      case EarningsPeriod.custom:
        if (from == null || to == null) {
          throw ArgumentError('Custom dates are required.');
        }
        start = DateTime(from.year, from.month, from.day);
        end = DateTime(to.year, to.month, to.day);
        if (end.isBefore(start)) {
          throw ArgumentError(
            'The end date must be on or after the start date.',
          );
        }
      case EarningsPeriod.all:
        break;
    }
    return Earnings._(
      records.where((record) {
        if (enterpriseId != null &&
            record['enterprise_id'].toString() != enterpriseId) {
          return false;
        }
        if (start == null) return true;
        final raw = record['occurred_on']?.toString() ?? '';
        final occurred = DateTime.tryParse(
          raw.length >= 10 ? raw.substring(0, 10) : raw,
        );
        return occurred != null &&
            !occurred.isBefore(start) &&
            !occurred.isAfter(end!);
      }).toList(),
    );
  }
  double get income => _total('income');
  double get expense => _total('expense');
  double get net => income - expense;
  double _total(String type) => transactions
      .where((t) => t['type'] == type)
      .fold(
        0.0,
        (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0),
      );
}

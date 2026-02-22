import 'package:hive/hive.dart';

class TransactionsStore {
  static final Box box =
  Hive.box('transactionsBox');

  static void addExpense({
    required double amount,
    required String description,
  }) {
    box.add({
      'type': 'expense',
      'amount': amount,
      'description': description,
      'date': DateTime.now().toString(),
    });
  }

  static void addWithdraw({
    required double amount,
    required String person,
    String? description,
  }) {
    box.add({
      'type': 'withdraw',
      'amount': amount,
      'person': person,
      'description': description ?? '',
      'date': DateTime.now().toString(),
    });
  }

  static List getAll() {
    return box.values.toList();
  }
}

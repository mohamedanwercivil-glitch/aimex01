import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/day_records_store.dart';
import 'sales/new_sale_screen.dart';
import 'sales/sales_return_screen.dart';
import 'purchase_screen.dart';
import 'expenses_screen.dart';
import 'settlement_screen.dart';
import 'supplier_settlement_screen.dart';
import 'withdraw_screen.dart';
import 'transfer_screen.dart';

class DailyActivityLogScreen extends StatefulWidget {
  const DailyActivityLogScreen({super.key});

  @override
  State<DailyActivityLogScreen> createState() => _DailyActivityLogScreenState();
}

class _DailyActivityLogScreenState extends State<DailyActivityLogScreen> {
  bool _isNavigating = false; // 🔥 حماية لمنع الفتح المتعدد

  @override
  Widget build(BuildContext context) {
    final allRecords = DayRecordsStore.getAll();
    final Map<String, Map<String, dynamic>> groupedRecords = {};
    
    for (var record in allRecords) {
      final id = record['invoiceId'] ?? record['id'] ?? record['time'];
      if (!groupedRecords.containsKey(id)) {
        groupedRecords[id.toString()] = record;
      }
    }

    final activities = groupedRecords.values.toList();
    activities.sort((a, b) => (b['time'] ?? b['date'] ?? '').toString().compareTo((a['time'] ?? a['date'] ?? '').toString()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل حركات اليوم'),
        centerTitle: true,
      ),
      body: activities.isEmpty
          ? const Center(child: Text('لا توجد حركات مسجلة اليوم'))
          : ListView.builder(
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return _buildActivityCard(activity);
              },
            ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    if (_isNavigating) return const SizedBox.shrink(); // منع العرض أثناء الانتقال لو لزم الأمر

    final type = activity['type'];
    final timeStr = activity['time'] ?? activity['date'] ?? '';
    String timeOnly = '';
    try {
      final dt = DateTime.parse(timeStr);
      timeOnly = DateFormat('hh:mm a').format(dt);
    } catch (_) {}

    IconData icon;
    Color color;
    String title;
    String subtitle;
    Widget targetScreen;

    switch (type) {
      case 'sale':
        icon = Icons.shopping_cart;
        color = Colors.green;
        title = 'فاتورة بيع: ${activity['customer']}';
        subtitle = 'إجمالي: ${activity['invoiceTotal']} | ${activity['paymentType']}';
        targetScreen = NewSaleScreen(editInvoiceId: activity['invoiceId']);
        break;
      case 'purchase':
        icon = Icons.shopping_bag;
        color = Colors.blue;
        title = 'فاتورة شراء: ${activity['supplier']}';
        subtitle = 'إجمالي: ${activity['invoiceTotal']} | ${activity['paymentType']}';
        targetScreen = PurchaseScreen(editInvoiceId: activity['invoiceId']);
        break;
      case 'sales_return':
        icon = Icons.assignment_return;
        color = Colors.orange;
        title = 'مرتجع مبيعات: ${activity['customer']}';
        subtitle = 'قيمة المرتجع: ${activity['invoiceTotal']}';
        targetScreen = SalesReturnScreen(editInvoiceId: activity['invoiceId']);
        break;
      case 'expense':
        icon = Icons.money_off;
        color = Colors.red;
        title = 'مصروف: ${activity['description']}';
        subtitle = 'المبلغ: ${activity['amount']} | ${activity['wallet']}';
        targetScreen = ExpensesScreen(editExpenseId: activity['id'] ?? activity['invoiceId']);
        break;
      case 'settlement':
        icon = Icons.person_add;
        color = Colors.teal;
        title = 'تحصيل من عميل: ${activity['customer']}';
        subtitle = 'المبلغ: ${activity['amount']} | ${activity['paymentType']}';
        targetScreen = SettlementScreen(editSettlementId: activity['id'] ?? activity['invoiceId']);
        break;
      case 'supplier_settlement':
        icon = Icons.payments;
        color = Colors.indigo;
        title = 'سداد لمورد: ${activity['supplier']}';
        subtitle = 'المبلغ: ${activity['amount']} | ${activity['wallet']}';
        targetScreen = SupplierSettlementScreen(editSettlementId: activity['id'] ?? activity['invoiceId']);
        break;
      case 'withdraw':
        icon = Icons.account_balance_wallet;
        color = Colors.brown;
        title = 'مسحوبات: ${activity['person']}';
        subtitle = 'المبلغ: ${activity['amount']} | ${activity['description']}';
        targetScreen = WithdrawScreen(editWithdrawId: activity['id'] ?? activity['invoiceId']);
        break;
      case 'transfer':
        icon = Icons.swap_horiz;
        color = Colors.purple;
        title = 'تحويل مالي';
        subtitle = 'من: ${activity['from']} إلى: ${activity['to']} | مبلغ: ${activity['amount']}';
        targetScreen = TransferScreen(editTransferId: activity['id'] ?? activity['invoiceId']);
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        title = 'عملية غير معروفة';
        subtitle = '';
        targetScreen = Container();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: _isNavigating ? null : () async {
          setState(() => _isNavigating = true);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
          );
          if (mounted) setState(() => _isNavigating = false);
        },
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            Text(timeOnly, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
        trailing: _isNavigating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.edit_note, color: Colors.grey),
      ),
    );
  }
}

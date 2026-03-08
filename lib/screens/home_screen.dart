import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/day_state.dart';
import '../widgets/base_scaffold.dart';
import 'start_day_screen.dart';
import 'purchase_screen.dart';
import 'sales/sales_screen.dart';
import 'sales/daily_invoices_screen.dart';
import 'daily_purchase_invoices_screen.dart';
import 'expenses_screen.dart';
import 'withdraw_screen.dart';
import 'inventory_screen.dart';
import 'end_day_screen.dart';
import 'settlement_screen.dart';
import 'supplier_settlement_screen.dart';
import 'settings/import_screen.dart';
import 'account_statement_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DayState>(
      builder: (context, dayState, child) {
        final dayStarted = dayState.dayStarted;

        return BaseScaffold(
          title: '', // تم إزالة العنوان
          body: LayoutBuilder(
            builder: (context, constraints) {
              // تصميم جديد لواجهة مرنة
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      // زر بداية اليوم بالعرض الكامل
                      if (!dayStarted)
                        _buildFullWidthButton(
                          context,
                          'بداية اليوم',
                          Icons.wb_sunny,
                          Colors.teal,
                          const StartDayScreen(),
                        ),
                      if (!dayStarted) const SizedBox(height: 16),

                      // صف البيع والشراء
                      Row(
                        children: [
                          _buildHalfWidthCard(context, 'بيع / مرتجع', Icons.point_of_sale, Colors.green, const SalesScreen(), enabled: dayStarted),
                          const SizedBox(width: 16),
                          _buildHalfWidthCard(context, 'شراء', Icons.shopping_cart, Colors.blue, const PurchaseScreen(), enabled: dayStarted),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // صف فواتير البيع والشراء
                      Row(
                        children: [
                          _buildHalfWidthCard(context, 'فواتير البيع', Icons.description, Colors.blueGrey, const DailyInvoicesScreen()),
                          const SizedBox(width: 16),
                          _buildHalfWidthCard(context, 'فواتير الشراء', Icons.receipt_long, Colors.blue.shade800, const DailyPurchaseInvoicesScreen()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // صف سداد العملاء والموردين
                      Row(
                        children: [
                          _buildHalfWidthCard(context, 'سداد العملاء', Icons.payments, Colors.indigo, const SettlementScreen(), enabled: dayStarted),
                          const SizedBox(width: 16),
                          _buildHalfWidthCard(context, 'سداد الموردين', Icons.assignment_return, Colors.brown, const SupplierSettlementScreen(), enabled: dayStarted),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // صف المسحوبات والمصروفات
                      Row(
                        children: [
                           _buildHalfWidthCard(context, 'مسحوبات شخصية', Icons.account_balance_wallet, Colors.orange, const WithdrawScreen(), enabled: dayStarted),
                           const SizedBox(width: 16),
                           _buildHalfWidthCard(context, 'مصروفات الشغل', Icons.receipt, Colors.purple, const ExpensesScreen(), enabled: dayStarted),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // الصف الأخير: كشف حساب وجرد
                      Row(
                        children: [
                          _buildHalfWidthCard(context, 'كشف حساب', Icons.account_balance, Colors.cyan.shade700, const AccountStatementScreen()),
                          const SizedBox(width: 16),
                          _buildHalfWidthCard(context, 'جرد المخزون', Icons.inventory, Colors.red, const InventoryScreen()),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // زر إنهاء اليوم
                      if (dayStarted)
                        _buildFullWidthButton(context, 'إنهاء اليوم', Icons.done_all, Colors.red.shade700, const EndDayScreen()),
                      const SizedBox(height: 12),
                      // زر استيراد
                      _buildFullWidthButton(context, 'استيراد من اكسل', Icons.file_upload, Colors.grey.shade700, const ImportScreen()),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHalfWidthCard(BuildContext context, String title, IconData icon, Color color, Widget screen, {bool enabled = true}) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled
            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
            : null,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: enabled ? color : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(15),
            boxShadow: enabled ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 3))] : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthButton(BuildContext context, String title, IconData icon, Color color, Widget screen, {bool enabled = true}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade400,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
        ),
        onPressed: enabled 
            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
            : null,
        icon: Icon(icon, size: 28),
        label: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/day_state.dart';
import '../widgets/base_scaffold.dart';
import 'start_day_screen.dart';
import 'purchase_screen.dart';
import 'sales/new_sale_screen.dart';
import 'expenses_screen.dart';
import 'withdraw_screen.dart';
import 'inventory_screen.dart';
import 'end_day_screen.dart';
import 'settlement_screen.dart';
import 'supplier_settlement_screen.dart';
import 'settings/import_screen.dart'; // Import the new screen

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Consumer to listen to DayState changes
    return Consumer<DayState>(
      builder: (context, dayState, child) {
        final dayStarted = dayState.dayStarted;

        return BaseScaffold(
          title: 'الصفحة الرئيسية',
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildCard(
                        context,
                        'بداية اليوم',
                        Icons.wb_sunny,
                        Colors.teal,
                        const StartDayScreen(),
                        enabled: !dayStarted,
                      ),
                      _buildCard(
                        context,
                        'شراء',
                        Icons.shopping_cart,
                        Colors.blue,
                        const PurchaseScreen(),
                        enabled: dayStarted,
                      ),
                      _buildCard(
                        context,
                        'بيع',
                        Icons.point_of_sale,
                        Colors.green,
                        const NewSaleScreen(),
                        enabled: dayStarted,
                      ),
                      _buildCard(
                        context,
                        'سداد العملاء',
                        Icons.payments,
                        Colors.indigo,
                        const SettlementScreen(),
                        enabled: dayStarted,
                      ),
                      _buildCard(
                        context,
                        'مصروفات الشغل',
                        Icons.receipt,
                        Colors.purple,
                        const ExpensesScreen(),
                        enabled: dayStarted,
                      ),
                      _buildCard(
                        context,
                        'مسحوبات شخصية',
                        Icons.account_balance_wallet,
                        Colors.orange,
                        const WithdrawScreen(),
                        enabled: dayStarted,
                      ),
                      _buildCard(
                        context,
                        'سداد الموردين',
                        Icons.assignment_return,
                        Colors.brown,
                        const SupplierSettlementScreen(),
                        enabled: dayStarted,
                      ),
                      _buildCard(
                        context,
                        'جرد المخزون',
                        Icons.search,
                        Colors.red,
                        const InventoryScreen(),
                        enabled: true, // Always enabled
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      disabledBackgroundColor: Colors.grey, 
                    ),
                    onPressed: dayStarted
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EndDayScreen(),
                              ),
                            );
                          }
                        : null,
                    child: const Text('إنهاء اليوم'),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ImportScreen(),
                        ),
                      );
                    },
                    child: const Text('استيراد من اكسل'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget screen, {
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => screen),
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? color : Colors.grey,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../widgets/base_scaffold.dart';
import 'start_day_screen.dart';
import 'purchase_screen.dart';
import 'sales/new_sale_screen.dart';
import 'expenses_screen.dart';
import 'withdraw_screen.dart';
import 'inventory_screen.dart';
import 'end_day_screen.dart';
import 'settlement_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  ),

                  _buildCard(
                    context,
                    'شراء',
                    Icons.shopping_cart,
                    Colors.blue,
                    const PurchaseScreen(),
                  ),

                  _buildCard(
                    context,
                    'بيع',
                    Icons.point_of_sale,
                    Colors.green,
                    const NewSaleScreen(),
                  ),

                  _buildCard(
                    context,
                    'سداد',
                    Icons.payments,
                    Colors.indigo,
                    const SettlementScreen(),
                  ),

                  _buildCard(
                    context,
                    'مصروفات',
                    Icons.receipt,
                    Colors.purple,
                    const ExpensesScreen(),
                  ),

                  _buildCard(
                    context,
                    'مسحوبات',
                    Icons.account_balance_wallet,
                    Colors.orange,
                    const WithdrawScreen(),
                  ),

                  _buildCard(
                    context,
                    'جرد المخزون',
                    Icons.search,
                    Colors.red,
                    const InventoryScreen(),
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
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EndDayScreen(),
                    ),
                  );
                },
                child: const Text('إنهاء اليوم'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
      BuildContext context,
      String title,
      IconData icon,
      Color color,
      Widget screen,
      ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
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

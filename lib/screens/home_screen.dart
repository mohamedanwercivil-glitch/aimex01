import 'dart:async';
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
import 'snapshots_screen.dart';
import '../services/logger_service.dart';
import '../services/backup_service.dart';
import '../services/background_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _backupTimer;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartTasks();
  }

  Future<void> _checkPermissionsAndStartTasks() async {
    // طلب استثناء توفير البطارية لضمان العمل في الخلفية بدقة
    await BackgroundService.requestBatteryOptimizationExemption();
    _startAutoBackupSequence();
  }

  void _startAutoBackupSequence() {
    _backupTimer?.cancel();
    _backupTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (context.read<DayState>().dayStarted) {
        BackupService.createAutoSnapshot();
      }
    });
  }

  @override
  void dispose() {
    _backupTimer?.cancel();
    super.dispose();
  }

  void _showEndDayConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('تأكيد إنهاء اليوم'),
          ],
        ),
        content: const Text(
          'هل النقدية (الكاش) والتحويلات مضبوطة لهذا اليوم؟\n\n'
          'إذا كانت هناك مصروفات أو سحوبات ناقصة، يرجى إضافتها قبل الإغلاق.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              LoggerService.userAction('إلغاء إنهاء اليوم (النقدية غير مضبوطة)');
              Navigator.pop(context);
            },
            child: const Text('غير مضبوطة (رجوع)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () {
              LoggerService.userAction('تأكيد إنهاء اليوم (النقدية مضبوطة)');
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EndDayScreen()));
            },
            child: const Text('مضبوطة (إتمام الإغلاق)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DayState>(
      builder: (context, dayState, child) {
        final dayStarted = dayState.dayStarted;

        return BaseScaffold(
          title: '',
          body: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      if (!dayStarted)
                        _buildFullWidthButton(
                          context,
                          'بداية اليوم',
                          Icons.wb_sunny,
                          Colors.teal,
                          const StartDayScreen(),
                          onTap: () async {
                            await BackupService.clearAllSnapshots();
                            await BackupService.createAutoSnapshot();
                            if (mounted) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const StartDayScreen()));
                            }
                          }
                        ),
                      if (!dayStarted) const SizedBox(height: 16),

                      Row(
                        children: [
                          _buildHalfWidthCard(context, 'بيع / مرتجع', Icons.point_of_sale, Colors.green, const SalesScreen(), enabled: dayStarted),
                          const SizedBox(width: 16),
                          _buildHalfWidthCard(context, 'شراء', Icons.shopping_cart, Colors.blue, const PurchaseScreen(), enabled: dayStarted),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          _buildHalfWidthCard(context, 'فواتير البيع', Icons.description, Colors.blueGrey, const DailyInvoicesScreen()),
                          const SizedBox(width: 16),
                          _buildHalfWidthCard(context, 'فواتير الشراء', Icons.receipt_long, Colors.blue.shade800, const DailyPurchaseInvoicesScreen()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          _buildHalfWidthCard(context, 'سداد العملاء', Icons.payments, Colors.indigo, const SettlementScreen(), enabled: dayStarted),
                          const SizedBox(width: 16),
                          _buildHalfWidthCard(context, 'سداد الموردين', Icons.assignment_return, Colors.brown, const SupplierSettlementScreen(), enabled: dayStarted),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                           _buildHalfWidthCard(context, 'مسحوبات شخصية', Icons.account_balance_wallet, Colors.orange, const WithdrawScreen(), enabled: dayStarted),
                           const SizedBox(width: 16),
                           _buildHalfWidthCard(context, 'مصروفات الشغل', Icons.receipt, Colors.purple, const ExpensesScreen(), enabled: dayStarted),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          _buildHalfWidthCard(context, 'كشف حساب', Icons.account_balance, Colors.cyan.shade700, const AccountStatementScreen()),
                          const SizedBox(width: 16),
                          _buildHalfWidthCard(context, 'جرد المخزون', Icons.inventory, Colors.red, const InventoryScreen()),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                           Expanded(
                             child: _buildActionButton(
                               context, 
                               'إرسال سجل الأخطاء', 
                               Icons.bug_report, 
                               Colors.red.shade900, 
                               null,
                               onTap: () => LoggerService.shareLogFile(),
                             ),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                             child: _buildActionButton(
                               context, 
                               'تصدير و استيراد النسخ الاحتياطيه', 
                               Icons.sync, 
                               Colors.grey.shade700, 
                               const ImportScreen(),
                             ),
                           ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildFullWidthButton(
                        context, 
                        'النسخ التلقائية (Snapshot)', 
                        Icons.history, 
                        Colors.orange.shade900, 
                        const SnapshotsScreen(),
                      ),
                      const SizedBox(height: 12),

                      if (dayStarted)
                        _buildFullWidthButton(
                          context, 
                          'إنهاء اليوم', 
                          Icons.done_all, 
                          Colors.red.shade700, 
                          null, 
                          onTap: () => _showEndDayConfirmation(context),
                        ),
                      const SizedBox(height: 20),
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

  Widget _buildFullWidthButton(BuildContext context, String title, IconData icon, Color color, Widget? screen, {bool enabled = true, VoidCallback? onTap}) {
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
            ? (onTap ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen!)))
            : null,
        icon: Icon(icon, size: 28),
        label: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String title, IconData icon, Color color, Widget? screen, {VoidCallback? onTap}) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap ?? () {
          if (screen != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
          }
        },
        icon: Icon(icon, size: 20),
        label: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

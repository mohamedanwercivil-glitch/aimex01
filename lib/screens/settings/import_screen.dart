import 'package:flutter/material.dart';
import '../../data/inventory_store.dart';
import '../../data/customer_store.dart';
import '../../data/supplier_store.dart';
import '../../services/toast_service.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد بيانات من إكسيل')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اختر نوع البيانات التي تود استيرادها من ملف إكسيل (.xlsx)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              
              // 1. استيراد الأصناف
              _buildImportButton(
                context,
                label: 'استيراد الأصناف',
                icon: Icons.inventory,
                onPressed: () async {
                  await InventoryStore.importFromExcel();
                  ToastService.show('تم استيراد الأصناف بنجاح');
                },
              ),
              
              const SizedBox(height: 15),
              
              // 2. استيراد الموردين (أسماء فقط)
              _buildImportButton(
                context,
                label: 'استيراد أسماء الموردين',
                icon: Icons.local_shipping,
                onPressed: () async {
                  // سنستخدم الدالة المحدثة التي تتعامل مع التنسيق الجديد للأسماء
                  await SupplierStore.importWithBalances(); 
                  ToastService.show('تم استيراد الموردين بنجاح');
                },
              ),
              
              const SizedBox(height: 15),
              
              // 3. استيراد العملاء (أسماء فقط)
              _buildImportButton(
                context,
                label: 'استيراد أسماء العملاء',
                icon: Icons.people,
                onPressed: () async {
                  await CustomerStore.importWithBalances();
                  ToastService.show('تم استيراد العملاء بنجاح');
                },
              ),

              const Divider(height: 40, thickness: 2),
              
              const Text(
                'استيراد الأرصدة والحسابات',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 20),

              // 4. استيراد حسابات الموردين
              _buildImportButton(
                context,
                label: 'استيراد حسابات الموردين',
                icon: Icons.account_balance_wallet,
                color: Colors.orange.shade700,
                onPressed: () async {
                  await SupplierStore.importWithBalances();
                  ToastService.show('تم استيراد حسابات الموردين بنجاح');
                },
              ),

              const SizedBox(height: 15),

              // 5. استيراد حسابات العملاء
              _buildImportButton(
                context,
                label: 'استيراد حسابات العملاء',
                icon: Icons.payments,
                color: Colors.green.shade700,
                onPressed: () async {
                  await CustomerStore.importWithBalances();
                  ToastService.show('تم استيراد حسابات العملاء بنجاح');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportButton(BuildContext context, {
    required String label, 
    required IconData icon, 
    required VoidCallback onPressed,
    Color? color,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: color != null ? Colors.white : null,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 17)),
    );
  }
}

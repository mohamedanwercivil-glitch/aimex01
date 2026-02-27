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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختر نوع البيانات التي تود استيرادها من ملف إكسيل (.xlsx)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            
            _buildImportButton(
              context,
              label: 'استيراد الأصناف',
              icon: Icons.inventory,
              onPressed: () async {
                await InventoryStore.importFromExcel();
                ToastService.show('تم استيراد الأصناف بنجاح');
              },
            ),
            
            const SizedBox(height: 20),
            
            _buildImportButton(
              context,
              label: 'استيراد الموردين',
              icon: Icons.local_shipping,
              onPressed: () async {
                await SupplierStore.importFromExcel();
                ToastService.show('تم استيراد الموردين بنجاح');
              },
            ),
            
            const SizedBox(height: 20),
            
            _buildImportButton(
              context,
              label: 'استيراد العملاء',
              icon: Icons.people,
              onPressed: () async {
                await CustomerStore.importFromExcel();
                ToastService.show('تم استيراد العملاء بنجاح');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton(BuildContext context, {
    required String label, 
    required IconData icon, 
    required VoidCallback onPressed
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 18)),
    );
  }
}

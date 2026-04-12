import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../data/inventory_store.dart';
import '../../data/customer_store.dart';
import '../../data/supplier_store.dart';
import '../../services/toast_service.dart';
import '../../services/backup_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _isProcessing = false;

  Future<void> _clearDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحذير: مسح شامل'),
        content: const Text('سيتم مسح كافة البيانات (أصناف، عملاء، موردين، فواتير، حسابات الخزنة) نهائياً من البرنامج. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، امسح الكل', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        final boxesToClear = [
          'inventoryBox',
          'customerBox',
          'customerInfoBox',
          'suppliers',
          'suppliersInfo',
          'dayRecordsBox',
          'dayBox',
          'salesDraftBox',
          'purchasesDraftBox',
          'transactionsBox'
        ];

        for (var boxName in boxesToClear) {
          if (Hive.isBoxOpen(boxName)) {
            await Hive.box(boxName).clear();
          } else {
            final box = await Hive.openBox(boxName);
            await box.clear();
          }
        }
        
        InventoryStore.refreshCache();
        CustomerStore.refreshCache();
        SupplierStore.refreshCache();
        
        ToastService.show('تمت تصفية كافة البيانات بنجاح');
        if (mounted) Navigator.pop(context);
      } catch (e) {
        ToastService.show('حدث خطأ أثناء المسح');
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة البيانات والنسخ الاحتياطي')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'النسخ الاحتياطي الكامل (ملف aimex)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _buildImportButton(
                          context,
                          label: 'تصدير ملف aimex',
                          icon: Icons.cloud_upload,
                          color: Colors.purple,
                          onPressed: () async {
                            setState(() => _isProcessing = true);
                            try {
                              await BackupService.exportBackup();
                              ToastService.show('تم تصدير النسخة الاحتياطية');
                            } catch (e) {
                              ToastService.show('فشل التصدير');
                            } finally {
                              setState(() => _isProcessing = false);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildImportButton(
                          context,
                          label: 'استيراد ملف aimex',
                          icon: Icons.cloud_download,
                          color: Colors.deepPurple,
                          onPressed: () async {
                            setState(() => _isProcessing = true);
                            try {
                              bool success = await BackupService.importBackup();
                              if (success) {
                                ToastService.show('تم استيراد كافة البيانات بنجاح');
                              }
                            } catch (e) {
                              ToastService.show('فشل الاستيراد');
                            } finally {
                              setState(() => _isProcessing = false);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'ملحوظة: ملف aimex يحتوي على كل البيانات (أصناف، عملاء، موردين، خزنة، لوج)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),

                  const Divider(height: 40, thickness: 2),
                  const Text(
                    'استيراد بيانات من إكسيل (.xlsx)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  
                  _buildImportButton(
                    context,
                    label: 'استيراد الأصناف',
                    icon: Icons.inventory,
                    onPressed: () async {
                      setState(() => _isProcessing = true);
                      try {
                        await InventoryStore.importFromExcel();
                        ToastService.show('تم استيراد الأصناف بنجاح');
                      } catch(e) {
                        ToastService.show('خطأ في الاستيراد');
                      } finally {
                        setState(() => _isProcessing = false);
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  
                  _buildImportButton(
                    context,
                    label: 'استيراد أسماء الموردين',
                    icon: Icons.local_shipping,
                    onPressed: () async {
                      setState(() => _isProcessing = true);
                      try {
                        await SupplierStore.importWithBalances(); 
                        ToastService.show('تم استيراد الموردين بنجاح');
                      } catch(e) {
                         ToastService.show('خطأ في الاستيراد');
                      } finally {
                        setState(() => _isProcessing = false);
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  
                  _buildImportButton(
                    context,
                    label: 'استيراد أسماء العملاء',
                    icon: Icons.people,
                    onPressed: () async {
                      setState(() => _isProcessing = true);
                      try {
                        await CustomerStore.importWithBalances();
                        ToastService.show('تم استيراد العملاء بنجاح');
                      } catch(e) {
                        ToastService.show('خطأ في الاستيراد');
                      } finally {
                        setState(() => _isProcessing = false);
                      }
                    },
                  ),

                  const Divider(height: 40, thickness: 2),
                  const Text(
                    'استيراد الأرصدة والحسابات من إكسيل',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 20),

                  _buildImportButton(
                    context,
                    label: 'استيراد حسابات الموردين',
                    icon: Icons.account_balance_wallet,
                    color: Colors.orange.shade700,
                    onPressed: () async {
                      setState(() => _isProcessing = true);
                      try {
                        await SupplierStore.importWithBalances();
                        ToastService.show('تم استيراد حسابات الموردين بنجاح');
                      } catch(e) {
                         ToastService.show('خطأ في الاستيراد');
                      } finally {
                        setState(() => _isProcessing = false);
                      }
                    },
                  ),
                  const SizedBox(height: 15),

                  _buildImportButton(
                    context,
                    label: 'استيراد حسابات العملاء',
                    icon: Icons.payments,
                    color: Colors.green.shade700,
                    onPressed: () async {
                      setState(() => _isProcessing = true);
                      try {
                        await CustomerStore.importWithBalances();
                        ToastService.show('تم استيراد حسابات العملاء بنجاح');
                      } catch(e) {
                        ToastService.show('خطأ في الاستيراد');
                      } finally {
                        setState(() => _isProcessing = false);
                      }
                    },
                  ),

                  const Divider(height: 50, thickness: 2),
                  
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'منطقة الخطر - إدارة البيانات',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _clearDatabase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          ),
                          icon: const Icon(Icons.delete_sweep),
                          label: const Text('مسح قاعدة البيانات بالكامل'),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'سيؤدي هذا لمسح كل البيانات لبدء استيراد شيتات جديدة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
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
      onPressed: _isProcessing ? null : onPressed,
      icon: Icon(icon),
      label: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
    );
  }
}

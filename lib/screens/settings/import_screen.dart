import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../data/inventory_store.dart';
import '../../data/customer_store.dart';
import '../../data/supplier_store.dart';
import '../../data/day_records_store.dart';
import '../../services/toast_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _isProcessing = false;
  bool _isAuthenticated = false;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('دخول الإدارة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى إدخال كلمة المرور للوصول لخدمات الاستيراد والمسح'),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_passwordController.text == 'MOHAMED') {
                setState(() {
                  _isAuthenticated = true;
                });
                Navigator.pop(context);
                _passwordController.clear();
              } else {
                ToastService.show('كلمة المرور خاطئة');
              }
            },
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }

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
          'purchasesDraftBox'
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
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('الإدارة')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text('هذه الشاشة محمية بكلمة مرور', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _showPasswordDialog,
                icon: const Icon(Icons.vpn_key),
                label: const Text('إدخال كلمة المرور'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('استيراد بيانات من إكسيل')),
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
                    'اختر نوع البيانات التي تود استيرادها من ملف إكسيل (.xlsx)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  
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
                    'استيراد الأرصدة والحسابات',
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
      label: Text(label, style: const TextStyle(fontSize: 17)),
    );
  }
}

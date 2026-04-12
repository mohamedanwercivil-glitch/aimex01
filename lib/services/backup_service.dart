import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/inventory_store.dart';
import '../data/customer_store.dart';
import '../data/supplier_store.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';

class BackupService {
  static const List<String> _allBoxes = [
    'inventoryBox',
    'customerBox',
    'customerInfoBox',
    'suppliers',
    'suppliersInfo',
    'dayRecordsBox',
    'dayBox',
    'transactionsBox',
    'salesDraftBox',
    'purchasesDraftBox',
  ];

  static Future<Directory?> _getPublicDirectory() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      
      if (status.isGranted) {
        final dir = Directory('/storage/emulated/0/aimex/backup');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    }
    
    final docDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${docDir.path}/aimex/backup');
    if (!await backupDir.exists()) await backupDir.create(recursive: true);
    return backupDir;
  }

  static Future<String> generateBackupFile() async {
    Map<String, dynamic> backupData = {};

    for (String boxName in _allBoxes) {
      final box = await Hive.openBox(boxName);
      backupData[boxName] = box.toMap().map((key, value) => MapEntry(key.toString(), value));
    }

    String jsonString = jsonEncode(backupData);
    final directory = await _getPublicDirectory();
    if (directory == null) return "";

    final file = File('${directory.path}/backup_${DateTime.now().millisecondsSinceEpoch}.aimex');
    await file.writeAsString(jsonString);
    return file.path;
  }

  static Future<void> exportBackup() async {
    final path = await generateBackupFile();
    if (path.isNotEmpty) {
      await Share.shareXFiles([XFile(path)], text: 'نسخة احتياطية لتطبيق Aimex');
    }
  }

  static Future<bool> importBackup() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      Map<String, dynamic> backupData = jsonDecode(content);

      for (String boxName in _allBoxes) {
        if (backupData.containsKey(boxName)) {
          final box = await Hive.openBox(boxName);
          await box.clear();
          Map<String, dynamic> data = Map<String, dynamic>.from(backupData[boxName]);
          await box.putAll(data);
        }
      }

      InventoryStore.refreshCache();
      CustomerStore.refreshCache();
      SupplierStore.refreshCache();
      DayState.instance.loadFromStorage();
      
      // 🔥 تحديث النقدية والمحافظ فوراً بعد الاستيراد
      CashState.instance.loadFromStorage();

      return true;
    }
    return false;
  }
}

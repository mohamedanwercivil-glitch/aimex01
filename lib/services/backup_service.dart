import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/inventory_store.dart';
import '../data/customer_store.dart';
import '../data/supplier_store.dart';
import '../state/day_state.dart';
import '../state/cash_state.dart';
import 'toast_service.dart';
import 'logger_service.dart';

class BackupService {
  static Timer? _autoBackupTimer;

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
    'cashStateBox',
  ];

  static void startAutoBackupTimer() {
    _autoBackupTimer?.cancel();
    
    Future.delayed(const Duration(seconds: 10), () {
      if (DayState.instance.dayStarted) {
        createAutoSnapshot();
      }
    });

    _autoBackupTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (DayState.instance.dayStarted) {
        createAutoSnapshot();
      }
    });
  }

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

  static Future<Directory> _getSnapshotDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/snapshots');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File?> createAutoSnapshot({String? suffix}) async {
    try {
      final data = await _captureAllData();
      final dir = await _getSnapshotDirectory();
      final now = DateTime.now();
      String fileName = 'snapshot_${now.hour}_${now.minute}_${now.second}';
      if (suffix != null) fileName += '_$suffix';
      fileName += '.aimex';
      
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonEncode(data));
      LoggerService.logicStep('تم إنشاء نسخة احتياطية: $fileName');
      return file;
    } catch (e) {
      LoggerService.error('فشل إنشاء النسخة التلقائية', error: e);
      return null;
    }
  }

  static Future<Map<String, dynamic>> _captureAllData() async {
    Map<String, dynamic> backupData = {};
    for (String boxName in _allBoxes) {
      final box = await Hive.openBox(boxName);
      backupData[boxName] = box.toMap().map((key, value) => MapEntry(key.toString(), value));
    }
    return backupData;
  }

  static Future<List<File>> getTodaySnapshots() async {
    final dir = await _getSnapshotDirectory();
    if (!await dir.exists()) return [];
    final files = dir.listSync().whereType<File>().toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  static Future<void> clearAllSnapshots() async {
    final dir = await _getSnapshotDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('restored_snapshot');
      await prefs.remove('safety_snapshot');
    }
  }

  static Future<void> restoreFromSnapshot(File file) async {
    try {
      // 1. إنشاء نسخة "أمان" من البيانات الحالية قبل الاستعادة
      final safetyFile = await createAutoSnapshot(suffix: 'SAFETY');
      final prefs = await SharedPreferences.getInstance();
      if (safetyFile != null) {
        await prefs.setString('safety_snapshot', safetyFile.path);
      }

      // 2. تنفيذ الاستعادة
      String content = await file.readAsString();
      Map<String, dynamic> backupData = jsonDecode(content);
      await _applyData(backupData);

      // 3. تعليم النسخة الحالية بأنها "مسترجعة"
      await prefs.setString('restored_snapshot', file.path);

      ToastService.show('تم استعادة البيانات بنجاح');
      LoggerService.logicStep('تم استعادة البيانات من نسخة تلقائية', data: {'file': file.path});
    } catch (e) {
      ToastService.show('فشل استعادة النسخة');
      LoggerService.error('فشل الاستعادة من Snapshot', error: e);
    }
  }

  static Future<void> _applyData(Map<String, dynamic> backupData) async {
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
    CashState.instance.loadFromStorage();
  }

  static Future<String> generateBackupFile() async {
    final data = await _captureAllData();
    String jsonString = jsonEncode(data);
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
      await _applyData(backupData);
      return true;
    }
    return false;
  }
}

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'toast_service.dart';

class LoggerService {
  static final DateFormat _fileDatePrefix = DateFormat('yyyy-MM-dd');
  static final DateFormat _timestampFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static SharedPreferences? _prefs;
  static bool _initialized = false;
  static String? _logDirPath;
  static int _txnCounter = 0;

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _txnCounter = _prefs!.getInt('txn_counter') ?? 0;

      final directory = await getApplicationDocumentsDirectory();
      _logDirPath = '${directory.path}/logs';
      final logDir = Directory(_logDirPath!);
      if (!await logDir.exists()) await logDir.create(recursive: true);

      _initialized = true;
      userAction('APP_START', {'version': '1.0.5', 'device': Platform.operatingSystem});
    } catch (e) {
      print('CRITICAL LOGGER ERROR: $e');
    }
  }

  static Future<void> log({
    String level = 'INFO',
    required String action,
    required String entity,
    String details = '-',
    String before = '-',
    String after = '-',
    String error = '-',
    String? txnId,
  }) async {
    if (!_initialized || _logDirPath == null) return;

    Future.microtask(() async {
      try {
        final now = DateTime.now();
        final timestamp = _timestampFormat.format(now);
        _txnCounter++;

        if (_txnCounter % 5 == 0) {
          _prefs?.setInt('txn_counter', _txnCounter);
        }

        // تمييز الأخطاء بشكل واضح جداً في الملف
        final prefix = level == 'ERROR' ? '❌ ❌ ❌ ' : '';
        final logEntry = '$prefix[$timestamp] [$level] | ACT: $action | ENT: $entity | TXN: ${txnId ?? "N/A"} | DET: $details | BEF: $before | AFT: $after | ERR: $error | #$_txnCounter';

        final logFile = File('$_logDirPath/${_fileDatePrefix.format(now)}.log');
        await logFile.writeAsString('$logEntry\n', mode: FileMode.append, flush: true);
      } catch (e) {
        // فشل صامت
      }
    });
  }

  static void userAction(String name, [Map<String, dynamic>? params]) =>
      log(action: 'USER_ACTION', entity: 'ui', details: '$name | params=$params');

  static void logicStep(String step, {String? txnId, Map<String, dynamic>? data}) =>
      log(action: 'LOGIC_STEP', entity: 'core', details: step, txnId: txnId, after: '$data');

  static void stateChange(String entity, dynamic before, dynamic after, {String? txnId}) =>
      log(action: 'STATE_CHANGE', entity: entity, before: '$before', after: '$after', txnId: txnId);

  static void error(String msg, {dynamic error, StackTrace? stackTrace, String? txnId}) =>
      log(level: 'ERROR', action: 'EXCEPTION', entity: 'system', error: '$msg | $error', details: 'STACK_TRACE: $stackTrace', txnId: txnId);

  static void warn(String msg, {String? txnId}) => log(level: 'WARNING', action: 'ALERT', entity: 'system', details: msg, txnId: txnId);

  static void logInventoryChange({
    required String itemName,
    required double qtyChange,
    required double before,
    required double after,
    required String reason,
    String? txnId,
  }) => log(
      action: 'INVENTORY_CHANGE',
      entity: 'item_$itemName',
      details: 'reason=$reason | change=$qtyChange',
      before: 'qty=$before',
      after: 'qty=$after',
      txnId: txnId
  );

  static void logFinanceChange({
    required String walletName,
    required double amount,
    required double before,
    required double after,
    required String reason,
    String? txnId,
  }) => log(
      action: 'FINANCE_CHANGE',
      entity: 'wallet_$walletName',
      details: 'reason=$reason | amount=$amount',
      before: 'bal=$before',
      after: 'bal=$after',
      txnId: txnId
  );

  static Future<void> shareLogFile() async {
    try {
      if (_logDirPath == null) return;
      
      final logDir = Directory(_logDirPath!);
      if (!await logDir.exists()) {
        ToastService.show('لا توجد سجلات حالية');
        return;
      }
      
      final List<FileSystemEntity> files = logDir.listSync();
      if (files.isEmpty) {
        ToastService.show('لا توجد سجلات حالية');
        return;
      }

      // ترتيب من الأحدث للأقدم
      files.sort((a, b) => b.path.compareTo(a.path));
      
      // إرسال آخر ملفين (اليوم وأمس) لضمان شمولية الأحداث
      final List<XFile> xFiles = [];
      for (var i = 0; i < files.length && i < 2; i++) {
        if (files[i] is File) {
          xFiles.add(XFile(files[i].path));
        }
      }
      
      if (xFiles.isNotEmpty) {
        ToastService.show('جاري تحضير تقرير الأخطاء...');
        await Share.shareXFiles(xFiles, text: 'سجل حركات وأخطاء Aimex - تاريخ ${DateTime.now()}');
      }
    } catch (e) {
      ToastService.show('خطأ أثناء مشاركة السجلات');
    }
  }

  static Future<void> cleanOldLogs() async {
    try {
      if (_logDirPath == null) return;
      final logDir = Directory(_logDirPath!);
      final now = DateTime.now();
      await for (var file in logDir.list()) {
        if (file is File) {
          final stats = await file.stat();
          if (now.difference(stats.modified).inDays > 7) {
            await file.delete();
          }
        }
      }
    } catch (e) {}
  }
}

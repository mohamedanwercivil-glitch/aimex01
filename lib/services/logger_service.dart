import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

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
      userAction('APP_START', {'version': '1.0.0'});
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
  }) async {
    if (!_initialized || _logDirPath == null) return;

    // تشغيل في الميكرو-تاسك لضمان عدم تعطيل الـ UI Thread
    Future.microtask(() async {
      try {
        final now = DateTime.now();
        final timestamp = _timestampFormat.format(now);
        _txnCounter++;

        // حفظ العداد كل 10 عمليات لتوفير استهلاك البطارية والسرعة
        if (_txnCounter % 10 == 0) {
          _prefs?.setInt('txn_counter', _txnCounter);
        }

        final logEntry = '$timestamp | $level | $action | $entity | $details | $before | $after | $error | TXN-$_txnCounter';

        final logFile = File('$_logDirPath/${_fileDatePrefix.format(now)}.log');

        // حذف flush: true لزيادة السرعة (النظام سيتولى الكتابة في الوقت المناسب)
        await logFile.writeAsString('$logEntry\n', mode: FileMode.append);
      } catch (e) {
        // فشل صامت
      }
    });
  }

  static void userAction(String name, [Map<String, dynamic>? params]) =>
      log(action: 'USER_ACTION', entity: 'ui', details: '$name | params=$params');

  static void logicEffect(String desc, [Map<String, dynamic>? impact]) =>
      log(action: 'LOGIC_EFFECT', entity: 'core', details: '$desc | impact=$impact');

  static void stateChange(String entity, dynamic before, dynamic after) =>
      log(action: 'STATE_CHANGE', entity: entity, before: '$before', after: '$after');

  static void error(String msg, {dynamic error, StackTrace? stackTrace}) =>
      log(level: 'ERROR', action: 'EXCEPTION', entity: 'system', error: '$msg | $error', details: 'stack=$stackTrace');

  static void warn(String msg) => log(level: 'WARNING', action: 'ALERT', entity: 'system', details: msg);

  static void logInventoryChange({
    required String itemName,
    required double qtyChange,
    required double before,
    required double after,
    required String reason,
  }) => log(
      action: 'INVENTORY_CHANGE',
      entity: 'item_$itemName',
      details: 'reason=$reason | change=$qtyChange',
      before: 'qty=$before',
      after: 'qty=$after'
  );

  static void logFinanceChange({
    required String walletName,
    required double amount,
    required double before,
    required double after,
    required String reason,
  }) => log(
      action: 'FINANCE_CHANGE',
      entity: 'wallet_$walletName',
      details: 'reason=$reason | amount=$amount',
      before: 'bal=$before',
      after: 'bal=$after'
  );

  static Future<void> shareLogFile() async {
    try {
      if (_logDirPath == null) return;
      final now = DateTime.now();
      final logFile = File('$_logDirPath/${_fileDatePrefix.format(now)}.log');
      if (await logFile.exists()) {
        await Share.shareXFiles([XFile(logFile.path)], text: 'سجل حركات Aimex');
      }
    } catch (e) {}
  }
}

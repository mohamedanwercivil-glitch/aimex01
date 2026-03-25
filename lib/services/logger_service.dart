import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// خدمة اللوج المحسنة: تسجل كل تفصيلة بدقة متناهية (Black Box)
/// الهدف: إعادة بناء السيناريو الذي أدى للمشكلة عند مراجعة الملف.
class LoggerService {
  static File? _logFile;
  static final DateFormat _timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  static Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      if (!await logDir.exists()) await logDir.create();
      
      _logFile = File('${logDir.path}/system_blackbox_log.txt');
      
      await _writeToDisk('\n\n================================================\n');
      await log('تشغيل التطبيق - جلسة جديدة', level: 'SESSION_START');
      await log('نظام التشغيل: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}', level: 'SYS_INFO');
    } catch (e) {
      print('CRITICAL: Failed to initialize logger: $e');
    }
  }

  static Future<void> log(String message, {String level = 'INFO', Map<String, dynamic>? data, dynamic error, StackTrace? stackTrace}) async {
    final timestamp = _timeFormat.format(DateTime.now());
    
    // بناء الرسالة بشكل منظم جداً
    StringBuffer buffer = StringBuffer();
    buffer.write('[$timestamp] [$level] $message');
    
    if (data != null && data.isNotEmpty) {
      buffer.write('\n    📊 البيانات: $data');
    }
    
    if (error != null) {
      buffer.write('\n    ❌ خطأ: $error');
    }
    
    if (stackTrace != null) {
      buffer.write('\n    📍 مسار الخطأ (Stack):\n$stackTrace');
    }
    
    final finalMsg = buffer.toString();
    print(finalMsg); // للعرض في الكونسول أثناء التطوير

    await _writeToDisk('$finalMsg\n');
  }

  static Future<void> _writeToDisk(String content) async {
    try {
      if (_logFile != null) {
        // استخدام append لضمان عدم مسح القديم، و flush لضمان الكتابة الفورية في حالة الانهيار
        await _logFile!.writeAsString(content, mode: FileMode.append, flush: true);
      }
    } catch (e) {
      print('ERROR WRITING LOG: $e');
    }
  }

  // --- دوال متخصصة لتسهيل التتبع ---

  /// تسجيل حركة قام بها المستخدم (ضغطة زر، فتح شاشة)
  static Future<void> userAction(String actionName, [Map<String, dynamic>? params]) => 
      log('المستخدم: $actionName', level: 'USER_UI', data: params);

  /// تسجيل تأثير منطقي (تعديل رصيد، خصم من مخزن)
  static Future<void> logicEffect(String description, [Map<String, dynamic>? impact]) => 
      log('تأثير منطقي: $description', level: 'LOGIC_CORE', data: impact);

  /// تسجيل حالة البيانات قبل وبعد عملية معينة
  static Future<void> stateChange(String entity, dynamic before, dynamic after) => 
      log('تغيير حالة: $entity', level: 'STATE_CHANGE', data: {'قبل': before, 'بعد': after});

  /// تسجيل الأخطاء البرمجية
  static Future<void> error(String msg, {dynamic error, StackTrace? stackTrace}) => 
      log(msg, level: 'ERROR_CRITICAL', error: error, stackTrace: stackTrace);

  // توافق مع الأكواد القديمة
  static Future<void> action(String msg) => userAction(msg);
  static Future<void> info(String msg) => log(msg, level: 'INFO');
  static Future<void> warn(String msg) => log(msg, level: 'WARN');
  static Future<void> logic(String msg) => logicEffect(msg);

  // دالة لجلب مسار الملف الحالي
  static String get logFilePath => _logFile?.path ?? '';

  static Future<void> shareLogFile() async {
    if (_logFile != null && await _logFile!.exists()) {
      await Share.shareXFiles([XFile(_logFile!.path)], text: 'ملخص تشخيص النظام (Black Box Log)');
    }
  }
}

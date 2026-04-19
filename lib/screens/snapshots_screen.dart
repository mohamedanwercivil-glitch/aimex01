import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backup_service.dart';
import '../services/toast_service.dart';
import '../services/logger_service.dart';

class SnapshotsScreen extends StatefulWidget {
  const SnapshotsScreen({super.key});

  @override
  State<SnapshotsScreen> createState() => _SnapshotsScreenState();
}

class _SnapshotsScreenState extends State<SnapshotsScreen> {
  List<File> _snapshots = [];
  bool _isLoading = true;
  String? _restoredPath;
  String? _safetyPath;

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  Future<void> _loadSnapshots() async {
    setState(() => _isLoading = true);
    final files = await BackupService.getTodaySnapshots();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _snapshots = files;
      _restoredPath = prefs.getString('restored_snapshot');
      _safetyPath = prefs.getString('safety_snapshot');
      _isLoading = false;
    });
  }

  void _confirmRestore(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد استعادة البيانات'),
        content: const Text('سيتم استبدال كل البيانات الحالية ببيانات هذه النسخة.\n\nسيقوم البرنامج تلقائياً بعمل نسخة "أمان" زرقاء لبياناتك الحالية قبل التغيير.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await BackupService.restoreFromSnapshot(file);
              LoggerService.userAction('استعادة بيانات من Snapshot', {'file': file.path});
              _loadSnapshots(); // تحديث الألوان بعد الاستعادة
            },
            child: const Text('تأكيد الاستعادة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نسخ احتياطية تلقائية (اليوم)'),
        actions: [
          IconButton(onPressed: _loadSnapshots, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _snapshots.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد نسخ تلقائية حتى الآن.\nالبرنامج يقوم بعمل نسخة كل 30 دقيقة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _snapshots.length,
                  itemBuilder: (context, index) {
                    final file = _snapshots[index];
                    final filePath = file.path;
                    final fileName = file.path.split('/').last;
                    
                    bool isRestored = _restoredPath == filePath;
                    bool isSafety = _safetyPath == filePath;
                    bool isManual = fileName.contains('SAFETY');

                    Color cardColor = Colors.white;
                    String statusText = 'تشمل: المخزن، الحسابات، والنقدية';
                    
                    if (isRestored) {
                      cardColor = Colors.yellow.shade100;
                      statusText = '⚠️ هذه هي النسخة التي تم استرجاعها حالياً';
                    } else if (isSafety || isManual) {
                      cardColor = Colors.blue.shade100;
                      statusText = '🛡️ نسخة أمان (تم أخذها قبل عملية استرجاع)';
                    }

                    // تنسيق الوقت
                    final parts = fileName.replaceFirst('.aimex', '').split('_');
                    String timeLabel = fileName;
                    if (parts.length >= 3) {
                      final hour = int.tryParse(parts[1]) ?? 0;
                      final minute = int.tryParse(parts[2]) ?? 0;
                      final dt = DateTime(2024, 1, 1, hour, minute);
                      timeLabel = 'نسخة احتياطية - ${DateFormat('hh:mm a').format(dt)}';
                    }

                    return Card(
                      color: cardColor,
                      elevation: isRestored ? 4 : 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isRestored ? Colors.orange : (isSafety ? Colors.blue : Colors.transparent),
                          width: isRestored || isSafety ? 2 : 0,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          isRestored ? Icons.assignment_turned_in : (isSafety ? Icons.security : Icons.history),
                          color: isRestored ? Colors.orange : (isSafety ? Colors.blue : Colors.grey),
                        ),
                        title: Text(timeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(statusText, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.green),
                              onPressed: () => Share.shareXFiles([XFile(file.path)], text: 'نسخة Aimex اللحظية'),
                            ),
                            const SizedBox(width: 4),
                            if (!isRestored)
                              ElevatedButton(
                                onPressed: () => _confirmRestore(file),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSafety ? Colors.blue.shade800 : Colors.orange.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                child: const Text('استعادة'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class ArabicUtils {
  static String normalize(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        // إزالة التشكيل (الحركات)
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .toLowerCase()
        .trim()
        // إزالة المسافات الزائدة
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

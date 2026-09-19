import 'package:intl/intl.dart';

class AppFormatters {
  static final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'ar_EG');
  static final NumberFormat _weightFormat = NumberFormat('#,##0.00', 'ar_EG');
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd', 'en_US');

  /// تنسيق العملة النقدية مع الرمز بالجنيه المصري
  static String formatCurrency(double amount) {
    return '${_currencyFormat.format(amount)} ج.م';
  }

  /// تنسيق الوزن بوحدة الطن
  static String formatWeight(double weight) {
    return '${_weightFormat.format(weight)} طن';
  }

  /// تنسيق التاريخ بصيغة قياسية
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// تنظيف وتوحيد اسم الصنف لمنع التكرار في المقارنات ومحرك FIFO
  static String normalizeItem(String item) {
    return item.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}

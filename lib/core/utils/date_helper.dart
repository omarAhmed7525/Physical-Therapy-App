import 'package:intl/intl.dart';

class DateHelper {
  /// Format a DateTime to 'yyyy/MM/dd' (e.g. 2026/06/30)
  static String formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  /// Format a DateTime to 'hh:mm a' in Arabic (e.g. 10:30 ص)
  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a', 'ar').format(date);
  }

  /// Get the Arabic month name for a given month number (1-12)
  static String getArabicMonthName(int month) {
    final date = DateTime(2026, month, 1);
    return DateFormat('MMMM', 'ar').format(date);
  }

  /// Get start of day (00:00:00)
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get end of day (23:59:59)
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }
}

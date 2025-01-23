import 'package:intl/intl.dart';

class DateFormatter {
  static String formatToDisplay(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd-MM-yy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  static String formatToStorage(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatFromCalendar(DateTime date) {
    return formatToStorage(date);
  }

  static bool isValidDate(String date) {
    try {
      DateTime.parse(date);
      return true;
    } catch (e) {
      return false;
    }
  }

  static DateTime parseDisplayDate(String displayDate) {
    try {
      // Parse date in format DD-MM-YY
      final parts = displayDate.split('-');
      if (parts.length != 3) throw FormatException('Invalid date format');

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      // Convert 2-digit year to full year
      final fullYear = year + (year >= 50 ? 1900 : 2000);

      return DateTime(fullYear, month, day);
    } catch (e) {
      throw FormatException('Invalid date format');
    }
  }
}

import 'package:intl/intl.dart';

/// A utility class for formatting dates with correct Buddhist Era (B.E.) year.
class DateFormatter {
  /// Formats a [DateTime] object into a string with the year converted to B.E.
  ///
  /// Example:
  /// `formatBE(DateTime(2024, 1, 1), 'dd/MM/yyyy')` will return `'01/01/2567'`.
  static String formatBE(DateTime dateTime, String pattern) {
    // Create a new DateTime object with the year adjusted for B.E.
    final beDateTime = DateTime(
      dateTime.year + 543,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
    );
    // Format the new DateTime object using the specified pattern and Thai locale.
    return DateFormat(pattern, 'th').format(beDateTime);
  }
}
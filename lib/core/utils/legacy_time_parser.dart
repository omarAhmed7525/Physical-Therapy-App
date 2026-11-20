/// Pure Dart utility functions for parsing legacy session time strings and
/// combining them with a session date.
class LegacyTimeParser {
  LegacyTimeParser._();

  /// Converts Arabic-Indic digits (٠-٩) and Persian digits (۰-۹) to ASCII (0-9).
  static String normalizeDigits(String input) {
    final buffer = StringBuffer();
    for (final char in input.runes) {
      // Arabic-Indic digits ٠ - ٩ (U+0660 - U+0669)
      if (char >= 0x0660 && char <= 0x0669) {
        buffer.writeCharCode(0x0030 + (char - 0x0660));
      }
      // Eastern Arabic / Persian digits ۰ - ۹ (U+06F0 - U+06F9)
      else if (char >= 0x06F0 && char <= 0x06F9) {
        buffer.writeCharCode(0x0030 + (char - 0x06F0));
      } else {
        buffer.writeCharCode(char);
      }
    }
    return buffer.toString();
  }

  /// Normalizes the time text:
  /// - Strips invisible formatting characters (U+200E, U+200F, U+202F, U+00A0, U+FEFF, etc.)
  /// - Converts digits to ASCII
  /// - Collapses multiple spaces
  /// - Trims leading/trailing whitespace
  static String normalizeTimeText(String raw) {
    if (raw.isEmpty) return '';

    // Strip invisible formatting characters
    final stripped = raw.replaceAll(
      RegExp(r'[\u200E\u200F\u202A-\u202E\u202F\u00A0\uFEFF]'),
      ' ',
    );

    // Convert non-ASCII digits
    final asciiDigits = normalizeDigits(stripped);

    // Normalize multiple spaces into single space and trim
    return asciiDigits.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Parses hour (0-23) and minute (0-59) from legacy time string.
  /// Returns `(hour, minute)` or `null` if parsing fails.
  static ({int hour, int minute})? parseTime(String timeText) {
    final cleaned = normalizeTimeText(timeText);
    if (cleaned.isEmpty) return null;

    // Pattern 1: HH:mm with optional AM/PM marker (e.g. "10:30 AM", "03:05 PM", "10:30 ص", "٠٣:٠٥ م", "10:30am")
    // Match: (hours):(minutes) (optional marker) OR marker (hours):(minutes)
    final match = RegExp(
      r'^(?:(?<markerBefore>[A-Za-z\u0600-\u06FF]+)\s*)?(?<hour>\d{1,2}):(?<minute>\d{2})(?:\s*(?<markerAfter>[A-Za-z\u0600-\u06FF]+))?$',
    ).firstMatch(cleaned);

    if (match == null) return null;

    final rawHour = int.tryParse(match.namedGroup('hour') ?? '');
    final rawMinute = int.tryParse(match.namedGroup('minute') ?? '');
    if (rawHour == null || rawMinute == null) return null;
    if (rawMinute < 0 || rawMinute > 59) return null;

    final marker = (match.namedGroup('markerAfter') ?? match.namedGroup('markerBefore') ?? '').trim().toLowerCase();

    // Determine AM / PM / 24-hour
    final isAM = marker == 'am' || marker == 'ص' || marker == 'صباحا' || marker == 'صباحاً';
    final isPM = marker == 'pm' || marker == 'م' || marker == 'مساء' || marker == 'مساءً';

    int hour = rawHour;

    if (isAM) {
      if (hour < 1 || hour > 12) return null;
      if (hour == 12) {
        hour = 0; // 12:xx AM -> 00:xx
      }
    } else if (isPM) {
      if (hour < 1 || hour > 12) return null;
      if (hour != 12) {
        hour += 12; // 01:xx PM -> 13:xx, 12:xx PM -> 12:xx
      }
    } else if (marker.isEmpty) {
      // 24-hour format: HH:mm (0 to 23)
      if (hour < 0 || hour > 23) return null;
    } else {
      // Unrecognized marker
      return null;
    }

    return (hour: hour, minute: rawMinute);
  }
}

/// Combines a legacy [date] (date portion) and [timeText] into a single [DateTime].
///
/// Rules:
/// - Arabic-Indic digits (٠-٩) and Persian digits -> ASCII.
/// - Strip U+200E/U+200F/U+202F/U+00A0 and extra spaces; trim.
/// - Accept `h:mm a`, `hh:mm a`, `HH:mm`; AM markers: `AM`, `am`, `ص`; PM markers: `PM`, `pm`, `م`.
/// - `12:xx AM` -> 00:xx. `12:xx PM` -> 12:xx.
/// - Result = the date's year/month/day (local) + parsed hour/minute.
/// - If parsing fails return null.
DateTime? combineLegacyDateAndTime(DateTime date, String timeText) {
  final parsed = LegacyTimeParser.parseTime(timeText);
  if (parsed == null) return null;

  return DateTime(
    date.year,
    date.month,
    date.day,
    parsed.hour,
    parsed.minute,
  );
}

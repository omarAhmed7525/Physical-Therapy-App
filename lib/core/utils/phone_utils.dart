import 'package:url_launcher/url_launcher.dart';

/// Pure phone utilities for normalization and WhatsApp link building.
abstract class PhoneUtils {
  /// Normalizes Egyptian phone number.
  /// If phone already starts with '+', returns as-is (digits/plus only).
  /// If phone starts with '0', strips leading 0 and prepends '+20'.
  /// Otherwise prepends '+20'.
  static String normalizeEgyptPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    if (cleaned.startsWith('00')) {
      return '+${cleaned.substring(2)}';
    }
    if (cleaned.startsWith('0')) {
      return '+20${cleaned.substring(1)}';
    }
    if (cleaned.startsWith('20')) {
      return '+$cleaned';
    }
    return '+20$cleaned';
  }

  /// Builds a WhatsApp URI:
  /// `https://wa.me/{normalizedPhone}?text={encodedMessage}`
  static Uri buildWhatsAppUri({
    required String phone,
    required String message,
  }) {
    final normalized = normalizeEgyptPhone(phone);
    final phoneWithoutPlus = normalized.startsWith('+') ? normalized.substring(1) : normalized;
    return Uri.parse('https://wa.me/$phoneWithoutPlus?text=${Uri.encodeComponent(message)}');
  }

  /// Launches WhatsApp with the given phone and message.
  /// Returns true if launched successfully, false otherwise.
  static Future<bool> launchWhatsApp({
    required String phone,
    required String message,
  }) async {
    final uri = buildWhatsAppUri(phone: phone, message: message);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}

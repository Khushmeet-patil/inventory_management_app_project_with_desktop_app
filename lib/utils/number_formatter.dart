import 'dart:ui';

class NumberFormatter {
  static const _gujaratiDigits = ['૦', '૧', '૨', '૩', '૪', '૫', '૬', '૭', '૮', '૯'];

  static String toGujaratiDigits(String number, Locale locale) {
    if (locale.languageCode != 'gu') return number; // Only convert for Gujarati
    return number.split('').map((digit) {
      int? digitValue = int.tryParse(digit);
      return digitValue != null ? _gujaratiDigits[digitValue] : digit;
    }).join();
  }
}
import 'package:flutter/services.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  const CurrencyInputFormatter({this.maxDigits = 12});

  final int maxDigits;

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String formatNumber(num value) {
    return formatDigits(value.round().toString());
  }

  static String formatDigits(String digits) {
    final cleanDigits = digitsOnly(digits);
    if (cleanDigits.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (var index = 0; index < cleanDigits.length; index++) {
      final remaining = cleanDigits.length - index;
      buffer.write(cleanDigits[index]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = digitsOnly(newValue.text);
    final limitedDigits = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;
    final formatted = formatDigits(limitedDigits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

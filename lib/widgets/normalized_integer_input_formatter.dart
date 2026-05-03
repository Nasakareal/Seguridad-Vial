import 'package:flutter/services.dart';

class NormalizedIntegerInputFormatter extends TextInputFormatter {
  const NormalizedIntegerInputFormatter();

  static String normalize(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalize(newValue.text);
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}

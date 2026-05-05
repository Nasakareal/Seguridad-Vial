import 'package:flutter/services.dart';

class NormalizedIntegerInputFormatter extends TextInputFormatter {
  final int? max;

  const NormalizedIntegerInputFormatter({this.max});

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
    var normalized = normalize(newValue.text);
    final maxValue = max;
    if (maxValue != null) {
      final parsed = int.tryParse(normalized);
      if (parsed != null && parsed > maxValue) {
        normalized = maxValue.toString();
      }
    }
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}

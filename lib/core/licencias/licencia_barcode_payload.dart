import 'dart:convert';
import 'dart:typed_data';

import 'package:mobile_scanner/mobile_scanner.dart';

class LicenciaBarcodePayload {
  const LicenciaBarcodePayload._();

  static String? fromBarcode(Barcode barcode) {
    final candidates = <String>[];

    void addText(String? value) {
      final text = (value ?? '').trim();
      if (text.isNotEmpty) candidates.add(text);
    }

    void addBytes(Uint8List? bytes) {
      if (bytes == null || bytes.isEmpty) return;
      addText(utf8.decode(bytes, allowMalformed: true));
      addText(latin1.decode(bytes, allowInvalid: true));
      addText(String.fromCharCodes(bytes));
    }

    addText(barcode.rawValue);
    addText(barcode.displayValue);

    final decoded = barcode.rawDecodedBytes;
    switch (decoded) {
      case DecodedBarcodeBytes(:final bytes):
        addBytes(bytes);
      case DecodedVisionBarcodeBytes(:final bytes, :final rawBytes):
        addBytes(bytes);
        addBytes(rawBytes);
      case null:
        break;
    }

    return _bestCandidate(candidates);
  }

  static String? _bestCandidate(List<String> candidates) {
    String? best;
    var bestScore = -1;

    for (final candidate in candidates) {
      final score = _score(candidate);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }

    if (best == null || bestScore <= 0) return null;
    return best;
  }

  static int _score(String value) {
    final text = value.trim();
    if (text.isEmpty) return 0;

    var score = 0;
    if (text.contains('//')) score += 80;
    if (RegExp(r'\d{5,}').hasMatch(text)) score += 25;
    if (RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{3,}').hasMatch(text)) score += 20;
    if (text.length >= 20) score += 10;
    if (text.length > 80) score += 10;
    score += text.length.clamp(0, 200).toInt();

    return score;
  }
}

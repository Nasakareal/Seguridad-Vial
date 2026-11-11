import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/core/coordinate_pair_parser.dart';

void main() {
  group('CoordinatePairParser', () {
    test('parses coordinates separated by comma', () {
      final pair = CoordinatePairParser.parse('19.7023456, -101.1923456');

      expect(pair, isNotNull);
      expect(pair!.latitude, 19.7023456);
      expect(pair.longitude, -101.1923456);
    });

    test('parses coordinates separated by whitespace or semicolon', () {
      expect(CoordinatePairParser.parse('19.7 -101.2')?.longitude, -101.2);
      expect(CoordinatePairParser.parse('19.7; -101.2')?.latitude, 19.7);
    });

    test('rejects malformed or out-of-range coordinates', () {
      expect(CoordinatePairParser.parse('Morelia'), isNull);
      expect(CoordinatePairParser.parse('91, -101.2'), isNull);
      expect(CoordinatePairParser.parse('19.7, -181'), isNull);
    });
  });
}

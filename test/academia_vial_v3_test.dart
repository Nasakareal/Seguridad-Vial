import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/modules/cultura_vial/academy/content/vial_question_bank.dart';

void main() {
  test('all visual scenes referenced by questions are available', () {
    for (final scene in vialQuestionBank.map((question) => question.illustration).toSet()) {
      final path = 'assets/cultura_vial/academia/$scene.png';
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('every topic has at least twelve questions', () {
    final counts = <String, int>{};
    for (final q in vialQuestionBank) {
      counts.update(q.category, (value) => value + 1, ifAbsent: () => 1);
    }
    expect(counts.length, 10);
    for (final count in counts.values) {
      expect(count, 12);
    }
  });
}

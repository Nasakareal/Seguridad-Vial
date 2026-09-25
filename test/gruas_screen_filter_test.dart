import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/gruas/gruas_screen.dart';

void main() {
  test('Conduce does not discard gruas because its UI id is negative', () {
    expect(
      gruaMatchesUnidadFilter(
        isConduce: true,
        unidadFiltroId: -2,
        unidadIds: const [1],
      ),
      isTrue,
    );
  });

  test('real units still require matching catalog assignment', () {
    expect(
      gruaMatchesUnidadFilter(
        isConduce: false,
        unidadFiltroId: 2,
        unidadIds: const [1],
      ),
      isFalse,
    );
  });
}

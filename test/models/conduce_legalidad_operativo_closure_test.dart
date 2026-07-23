import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';

void main() {
  group('cierre de alcoholimetria', () {
    final createdAt = DateTime.utc(2026, 7, 22, 16);

    ConduceLegalidadOperativo operativo({
      String tipo = 'alcoholimetria',
      bool canFeed = true,
    }) {
      return ConduceLegalidadOperativo(
        id: 1,
        nombre: 'Operativo Alcoholimetria',
        tipoOperativo: tipo,
        estado: 'activo',
        createdAt: createdAt,
        canFeed: canFeed,
        totalCapturas: 0,
        misCapturas: 0,
      );
    }

    test('permite alimentar justo antes de las 8 horas', () {
      final item = operativo();

      expect(
        item.canFeedAt(
          createdAt
              .add(const Duration(hours: 8))
              .subtract(const Duration(microseconds: 1)),
          isSuperadmin: false,
        ),
        isTrue,
      );
    });

    test('cierra exactamente al cumplir 8 horas', () {
      final item = operativo();

      expect(
        item.canFeedAt(
          createdAt.add(const Duration(hours: 8)),
          isSuperadmin: false,
        ),
        isFalse,
      );
    });

    test('superadmin conserva acceso despues del cierre', () {
      final item = operativo(canFeed: false);

      expect(
        item.canFeedAt(
          createdAt.add(const Duration(days: 1)),
          isSuperadmin: true,
        ),
        isTrue,
      );
    });

    test('no aplica el cierre de 8 horas a otros operativos', () {
      final item = operativo(tipo: 'conduce_legalidad');

      expect(
        item.canFeedAt(
          createdAt.add(const Duration(days: 1)),
          isSuperadmin: false,
        ),
        isTrue,
      );
    });
  });
}

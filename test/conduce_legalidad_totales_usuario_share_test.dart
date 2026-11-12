import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';
import 'package:seguridad_vial_app/services/conduce_legalidad_share_service.dart';

void main() {
  test('exporta totales por usuario con todos los folios de boleta', () {
    const ana = ConduceLegalidadUserRef(id: 10, nombre: 'Ana Pérez');
    const luis = ConduceLegalidadUserRef(id: 11, nombre: 'Luis García');
    const operativo = ConduceLegalidadOperativo(
      id: 82,
      nombre: 'Conduce con Legalidad',
      lugar: 'Calzada La Huerta',
      fecha: '2026-11-12',
      estado: 'activo',
      totalCapturas: 3,
      misCapturas: 0,
      capturas: <ConduceLegalidadCaptura>[
        ConduceLegalidadCaptura(
          id: 900,
          folioNumero: 282,
          operativoId: 82,
          creador: ana,
          canEdit: false,
          vehiculos: <ConduceLegalidadVehiculo>[],
          personas: <ConduceLegalidadPersona>[],
        ),
        ConduceLegalidadCaptura(
          id: 901,
          folioNumero: 280,
          operativoId: 82,
          creador: luis,
          canEdit: false,
          vehiculos: <ConduceLegalidadVehiculo>[],
          personas: <ConduceLegalidadPersona>[],
        ),
        ConduceLegalidadCaptura(
          id: 902,
          folio: 'CL-82-283',
          operativoId: 82,
          creador: ana,
          canEdit: false,
          vehiculos: <ConduceLegalidadVehiculo>[],
          personas: <ConduceLegalidadPersona>[],
        ),
      ],
    );

    final text = ConduceLegalidadShareService.construirTotalesPorUsuario(
      operativo,
    );

    expect(text, contains('Operativo: CL-82'));
    expect(text, contains('Total general: 3 boletas'));
    expect(text, contains('Ana Pérez — 2 boletas'));
    expect(text, contains('CL-82-282, CL-82-283'));
    expect(text, contains('Luis García — 1 boleta'));
    expect(text, contains('CL-82-280'));
  });

  test('usa el id de captura cuando una boleta antigua no tiene folio', () {
    const operativo = ConduceLegalidadOperativo(
      id: 7,
      nombre: 'Conduce con Legalidad',
      estado: 'cerrado',
      totalCapturas: 1,
      misCapturas: 0,
      capturas: <ConduceLegalidadCaptura>[
        ConduceLegalidadCaptura(
          id: 44,
          operativoId: 7,
          createdBy: 5,
          agenteNombre: 'Agente histórico',
          canEdit: false,
          vehiculos: <ConduceLegalidadVehiculo>[],
          personas: <ConduceLegalidadPersona>[],
        ),
      ],
    );

    final text = ConduceLegalidadShareService.construirTotalesPorUsuario(
      operativo,
    );

    expect(text, contains('Agente histórico — 1 boleta'));
    expect(text, contains('CL-7-44'));
  });
}

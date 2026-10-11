import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_captura_show_screen.dart';

void main() {
  testWidgets('muestra la captura completa en secciones estructuradas', (
    tester,
  ) async {
    const fundamento = ConduceLegalidadFundamento(
      id: 7,
      codigo: 'ART-123',
      nombre: 'Conducir sin licencia',
      fundamentoLegal: 'Artículo 123, fracción I.',
      puntos: 3,
      retencionVehiculo: true,
      resumenSanciones: 'Depósito del vehículo',
    );
    const operativo = ConduceLegalidadOperativo(
      id: 22,
      nombre: 'Operativo conduce con legalidad',
      tipoOperativo: 'conduce_legalidad',
      estado: 'activo',
      totalCapturas: 1,
      misCapturas: 1,
    );
    const captura = ConduceLegalidadCaptura(
      id: 52,
      operativoId: 22,
      fundamentos: <ConduceLegalidadFundamento>[fundamento],
      agenteNombre: 'María López',
      agenteNumeroPlaca: 'SV-100',
      fecha: '2026-10-11',
      hora: '18:30:00',
      municipio: 'Morelia',
      lugar: 'Avenida Camelinas',
      coordenadasTexto: '19.6861000, -101.1974000',
      narrativa: 'Se realizó la inspección preventiva.',
      observaciones: 'Sin novedad adicional.',
      canEdit: true,
      vehiculos: <ConduceLegalidadVehiculo>[
        ConduceLegalidadVehiculo(
          marca: 'ITALIKA',
          linea: 'FT150',
          modelo: '2024',
          color: 'Negro',
          placas: 'ABC123',
          serie: 'SERIE123',
          numeroInventario: '0801',
          corralon: 'GALVÁN',
          retencionVehiculo: true,
        ),
      ],
      personas: <ConduceLegalidadPersona>[
        ConduceLegalidadPersona(
          nombre: 'Juan Pérez García',
          edad: 31,
          telefono: '4431234567',
          domicilio: 'Morelia, Michoacán',
          tipoLicencia: 'Motociclista',
          numeroLicencia: 'LIC-123',
          vigenciaLicencia: '2028-01-01',
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ConduceLegalidadCapturaShowScreen(
          operativo: operativo,
          captura: captura,
        ),
      ),
    );

    expect(find.text('Detalle CL-22-52'), findsOneWidget);
    expect(find.text('Intervención'), findsOneWidget);
    expect(find.text('Ubicación'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Fundamento'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Fundamento'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Vehículo 1 · ITALIKA FT150 2024'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Número de inventario'), findsOneWidget);
    expect(find.text('0801'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Persona 1 · Juan Pérez García'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('4431234567'), findsOneWidget);
    expect(find.text('LIC-123'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Sin novedad adicional.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sin novedad adicional.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

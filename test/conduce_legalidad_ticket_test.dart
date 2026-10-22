import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_boleta_screen.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_module.dart';

void main() {
  ConduceLegalidadOperativo operativo(String tipo) {
    return ConduceLegalidadOperativo(
      id: 11,
      nombre: tipo == 'alcoholimetria'
          ? 'Operativo Alcoholimetría'
          : 'Operativo conduce con legalidad',
      tipoOperativo: tipo,
      estado: 'activo',
      totalCapturas: 1,
      misCapturas: 1,
    );
  }

  test('el ticket conserva el nombre exacto de Alcoholimetría', () {
    final item = operativo('alcoholimetria');

    expect(item.ticketOperativoTitle, 'OPERATIVO DE ALCOHOLIMETRÍA');
    expect(item.ticketFolioPrefix, 'PA');
    expect(item.ticketOperativoTitle, contains('Í'));
    expect(item.ticketOperativoTitle, isNot(contains('PREVENCIÓN')));
    expect(item.ticketOperativoTitle, isNot(contains('CONDUCE')));

    final thermal = ThermalTicketRowFormatter(width: 48)
      ..center(item.ticketOperativoTitle);
    expect(thermal.toString().trim(), 'OPERATIVO DE ALCOHOLIMETRIA');
  });

  test('el ticket de Conduce con Legalidad conserva su identidad', () {
    final item = operativo('conduce_legalidad');

    expect(item.ticketOperativoTitle, 'OPERATIVO CONDUCE CON LEGALIDAD');
    expect(item.ticketFolioPrefix, 'CL');
    expect(item.ticketOperativoTitle, isNot(contains('PREVENCIÓN')));
    expect(
      ConduceLegalidadOperativo.ticketCoordinadorNombre,
      'Lic. Luis Roberto Rosiles Soberanis',
    );
    expect(
      ConduceLegalidadOperativo.ticketCoordinadorCargo,
      'Coordinador del Agrupamiento de Seguridad Vial',
    );
  });

  testWidgets('la boleta muestra inventario y corralón con tamaño normal', (
    tester,
  ) async {
    final item = operativo('conduce_legalidad');
    const captura = ConduceLegalidadCaptura(
      id: 12,
      operativoId: 11,
      agenteNombre: 'Ana María Pérez López',
      agenteNumeroPlaca: 'PLACA-7788',
      agenteAdscripcion: 'Unidad de Protección en Vialidades Urbanas',
      canEdit: true,
      vehiculos: <ConduceLegalidadVehiculo>[
        ConduceLegalidadVehiculo(
          placas: 'ABC-123-A',
          numeroInventario: '00042',
          corralonId: 8,
          corralon: 'CORRALÓN MORELIA',
        ),
      ],
      personas: <ConduceLegalidadPersona>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ConduceLegalidadBoletaScreen(
          initialOperativo: item,
          initialCaptura: captura,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NÚMERO DE INVENTARIO:'), findsOneWidget);
    expect(find.text('00042'), findsOneWidget);
    expect(find.text('CORRALÓN DE DESTINO:'), findsOneWidget);
    expect(find.text('CORRALÓN MORELIA'), findsOneWidget);
    expect(find.text('Ana María Pérez López'), findsOneWidget);
    expect(find.text('PLACA-7788'), findsOneWidget);
    expect(
      find.text('Unidad de Protección en Vialidades Urbanas'),
      findsOneWidget,
    );
    expect(
      find.text('Coordinador del Agrupamiento de Seguridad Vial:'),
      findsOneWidget,
    );
    expect(find.text('Lic. Luis Roberto Rosiles Soberanis'), findsOneWidget);
    expect(find.text('RESPONSABLES DEL OPERATIVO'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Lic. Luis Roberto Rosiles Soberanis')).dy,
      lessThan(tester.getTopLeft(find.text('AGENTE')).dy),
    );
    expect(
      tester.getTopLeft(find.text('AGENTE')).dy,
      lessThan(tester.getTopLeft(find.text('Firma autógrafa/electrónica:')).dy),
    );
    expect(tester.widget<Text>(find.text('00042')).style?.fontSize, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el inventario se previsualiza separado de la boleta', (
    tester,
  ) async {
    final item = operativo('conduce_legalidad');
    const captura = ConduceLegalidadCaptura(
      id: 12,
      operativoId: 11,
      folio: 'CL-11-12',
      fecha: '2026-10-19',
      hora: '10:30',
      lugar: 'Uruapan',
      agenteNombre: 'María Policía',
      agenteNumeroPlaca: 'SV-101',
      canEdit: true,
      vehiculos: <ConduceLegalidadVehiculo>[
        ConduceLegalidadVehiculo(
          marca: 'Honda',
          linea: 'Cargo',
          modelo: '2024',
          color: 'Rojo',
          placas: 'ABC-123-A',
          serie: '3H1TEST1234567890',
          numeroInventario: '00042',
          grua: 'Grúas Uruapan',
          corralon: 'Corralón Uruapan',
          partesDanadas: 'Rayón en costado derecho',
          observaciones: 'Casco bajo el asiento',
        ),
      ],
      personas: <ConduceLegalidadPersona>[
        ConduceLegalidadPersona(nombre: 'Juan Propietario'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ConduceLegalidadBoletaScreen(
          initialOperativo: item,
          initialCaptura: captura,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();

    expect(find.text('INVENTARIO DE VEHÍCULO REMITIDO'), findsOneWidget);
    expect(find.text('PREVIO AL ARRASTRE · ARTÍCULO 352'), findsOneWidget);
    expect(find.text('00042'), findsOneWidget);
    expect(find.text('Grúas Uruapan'), findsWidgets);
    expect(find.text('Corralón Uruapan'), findsOneWidget);
    expect(find.text('Objetos y accesorios inventariados:'), findsOneWidget);
    expect(find.text('PROPIETARIO / CONDUCTOR'), findsOneWidget);
    expect(find.text('AGENTE QUE ELABORA'), findsOneWidget);
    expect(find.text('OPERADOR DE GRÚA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una captura histórica sin folio no genera inventario nuevo', (
    tester,
  ) async {
    final item = operativo('conduce_legalidad');
    const captura = ConduceLegalidadCaptura(
      id: 10,
      operativoId: 11,
      canEdit: true,
      vehiculos: <ConduceLegalidadVehiculo>[
        ConduceLegalidadVehiculo(placas: 'HIST-001'),
      ],
      personas: <ConduceLegalidadPersona>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ConduceLegalidadBoletaScreen(
          initialOperativo: item,
          initialCaptura: captura,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();

    expect(find.text('INVENTARIO DE VEHÍCULO REMITIDO'), findsNothing);
    expect(
      find.textContaining('anterior al inicio de la serie digital'),
      findsOneWidget,
    );
  });

  test('el inventario térmico incluye vehículo, artículo y tres firmas', () {
    final item = operativo('conduce_legalidad');
    const captura = ConduceLegalidadCaptura(
      id: 12,
      operativoId: 11,
      fecha: '2026-10-19',
      hora: '10:30',
      agenteNombre: 'María Policía',
      agenteNumeroPlaca: 'SV-101',
      canEdit: true,
      vehiculos: <ConduceLegalidadVehiculo>[
        ConduceLegalidadVehiculo(
          placas: 'ABC-123-A',
          serie: '3H1TEST1234567890',
          numeroInventario: '00042',
          grua: 'Grúas Uruapan',
          corralon: 'Corralón Uruapan',
        ),
      ],
      personas: <ConduceLegalidadPersona>[
        ConduceLegalidadPersona(nombre: 'Juan Propietario'),
      ],
    );

    final text = buildConduceLegalidadInventoryTicketText(
      operativo: item,
      captura: captura,
      width: 48,
    );

    expect(text, contains('INVENTARIO DE VEHICULO REMITIDO'));
    expect(text, contains('ARTICULO 352'));
    expect(text, contains('00042'));
    expect(text, contains('ABC-123-A'));
    expect(text, contains('Numero de sello'));
    expect(text, contains('PROPIETARIO / CONDUCTOR'));
    expect(text, contains('AGENTE QUE ELABORA'));
    expect(text, contains('OPERADOR DE GRUA'));
  });

  test('tickets de ambos operativos usan la dirección de su delegación', () {
    for (final tipo in const ['conduce_legalidad', 'alcoholimetria']) {
      final item = ConduceLegalidadOperativo.fromJson({
        'id': 11,
        'nombre': tipo,
        'tipo_operativo': tipo,
        'unidad_id': 2,
        'delegacion_id': 6,
        'estado': 'activo',
        'delegacion': {
          'id': 6,
          'nombre': 'Pátzcuaro',
          'direccion_completa':
              'Av. Lázaro Cárdenas 120, Centro, Pátzcuaro, Mich.',
        },
      });

      final texto = ConduceLegalidadBoletaLegalText.informacionLiberacion(
        const ConduceLegalidadVehiculo(retencionVehiculo: true),
        esDelegaciones: item.unidadId == 2,
        delegacion: item.delegacion,
      );

      expect(texto, contains('Delegación de Pátzcuaro'));
      expect(texto, contains('Av. Lázaro Cárdenas 120'));
      expect(texto, contains('9:00 a. m. a 3:00 p. m.'));
      expect(texto, isNot(contains('4:00 p. m.')));
      expect(texto, isNot(contains('Justicia Cívica')));
      expect(texto, isNot(contains('Periférico Paseo')));
    }
  });

  test('delegación sin domicilio no cae en la dirección fija de Morelia', () {
    final texto = ConduceLegalidadBoletaLegalText.informacionLiberacion(
      const ConduceLegalidadVehiculo(retencionVehiculo: true),
      esDelegaciones: true,
      delegacion: const ConduceLegalidadRef(id: 6, nombre: 'Pátzcuaro'),
    );

    expect(texto, contains('Delegación de Pátzcuaro'));
    expect(texto, contains('9:00 a. m. a 3:00 p. m.'));
    expect(texto, isNot(contains('Morelia')));
    expect(texto, isNot(contains('4433163728')));
  });

  test('Morelia usa el mismo aviso de Siniestros hasta las 16:00', () {
    final texto = ConduceLegalidadBoletaLegalText.informacionLiberacion(
      const ConduceLegalidadVehiculo(retencionVehiculo: true),
    );

    expect(texto, contains('Unidad de Atención a Siniestros'));
    expect(texto, contains('4:00 p. m.'));
    expect(texto, isNot(contains('3:00 p. m.')));
    expect(texto, isNot(contains('18:00')));
  });

  test('el operativo conserva el supervisor enviado por el backend', () {
    final item = ConduceLegalidadOperativo.fromJson({
      'id': 11,
      'nombre': 'Operativo de Alcoholimetría',
      'tipo_operativo': 'alcoholimetria',
      'unidad_id': 2,
      'delegacion_id': 6,
      'estado': 'activo',
      'supervisor': {
        'nombre': 'Ángel Peralta Hernández',
        'cargo': 'Delegado de la Delegación de Pátzcuaro',
      },
    });

    expect(item.supervisor?.nombre, 'Ángel Peralta Hernández');
    expect(item.supervisor?.cargo, 'Delegado de la Delegación de Pátzcuaro');
    expect(item.supervisor?.nombre, isNot(contains('Lugo')));
  });

  test('una delegación nunca usa a Lugo como respaldo', () {
    final item = ConduceLegalidadOperativo.fromJson({
      'id': 11,
      'nombre': 'Operativo conduce con legalidad',
      'unidad_id': 2,
      'delegacion_id': 6,
      'estado': 'activo',
      'delegacion': {'id': 6, 'nombre': 'Pátzcuaro'},
    });

    expect(item.ticketSupervisorNombre, 'Delegado no asignado');
    expect(
      item.ticketSupervisorCargo,
      'Delegado de la Delegación de Pátzcuaro',
    );
    expect(item.ticketSupervisorNombre, isNot(contains('Lugo')));
  });

  test('fecha y hora caben juntas en el ancho legible de 58 mm', () {
    final writer = ThermalTicketRowFormatter(width: 32);

    writer.pairRow('Fecha', '2026-07-25', 'Hora', '21:30');

    final line = writer.toString().trim();
    expect(line, contains('Fecha: 2026-07-25'));
    expect(line, contains('Hora: 21:30'));
    expect(line.split('\n'), hasLength(1));
  });

  test('una fila larga cae de forma segura a dos renglones', () {
    final writer = ThermalTicketRowFormatter(width: 32);

    writer.pairRow('Placas/permiso', 'ABC-123-A', 'Estado placas', 'Michoacán');

    expect(writer.toString().trim().split('\n').length, greaterThan(1));
  });

  test('la salida térmica reemplaza acentos y símbolos por ASCII', () {
    final writer = ThermalTicketRowFormatter(width: 48);

    writer.line('PREVENCIÓN ÁÉÍÓÚ Ü Ñ ¿acción! 20°');

    final output = writer.toString().trim();
    expect(output, 'PREVENCION AEIOU U N ?accion! 20 grados');
    expect(output.codeUnits.every((byte) => byte <= 0x7F), isTrue);
  });

  test('el ticket usa una sola vez el fundamento unificado', () {
    const fundamento = ConduceLegalidadFundamento(
      id: 20,
      codigo: 'ART419_MOTO_CASCO',
      nombre: 'Motocicleta sin casco',
      articulo: '419',
      fraccion: 'II',
      puntos: 3,
      arrestoPersona: true,
      retencionVehiculo: true,
      resumenSanciones: 'arresto + 3 puntos + depósito',
      narrativaSugerida: 'Se detecta motocicleta sin casco.',
    );
    const vehiculo = ConduceLegalidadVehiculo(
      placas: 'ABC-123-A',
      retencionVehiculo: true,
      infraccion: fundamento,
    );
    const persona = ConduceLegalidadPersona(
      nombre: 'PERSONA PRUEBA',
      infraccion: fundamento,
    );
    const captura = ConduceLegalidadCaptura(
      id: 12,
      operativoId: 11,
      infraccion: fundamento,
      narrativa: 'Intervención en operativo.',
      canEdit: true,
      vehiculos: [vehiculo],
      personas: [persona],
    );

    final legal = ConduceLegalidadBoletaLegalText.fundamentoInfraccion(
      captura,
      vehiculo,
      persona,
    );
    final conducta = ConduceLegalidadBoletaLegalText.conducta(
      captura,
      vehiculo,
      persona,
    );

    expect(legal, contains('Intervención'));
    expect(legal, isNot(contains('Persona infractora')));
    expect(legal, isNot(contains('Vehículo:')));
    expect('Intervención'.allMatches(legal), hasLength(1));
    expect(
      'Se detecta motocicleta sin casco.'.allMatches(conducta),
      hasLength(1),
    );
  });

  test('el ticket conserva fundamentos separados de capturas anteriores', () {
    const personaFundamento = ConduceLegalidadFundamento(
      id: 21,
      nombre: 'Sanción de persona',
      articulo: '419',
      puntos: 1,
      retencionVehiculo: false,
    );
    const vehiculoFundamento = ConduceLegalidadFundamento(
      id: 22,
      nombre: 'Retiro de vehículo',
      articulo: '420',
      puntos: 0,
      retencionVehiculo: true,
    );
    const vehiculo = ConduceLegalidadVehiculo(
      retencionVehiculo: true,
      infraccion: vehiculoFundamento,
    );
    const persona = ConduceLegalidadPersona(infraccion: personaFundamento);
    const captura = ConduceLegalidadCaptura(
      id: 13,
      operativoId: 11,
      canEdit: true,
      vehiculos: [vehiculo],
      personas: [persona],
    );

    final legal = ConduceLegalidadBoletaLegalText.fundamentoInfraccion(
      captura,
      vehiculo,
      persona,
    );

    expect(legal, contains('Persona infractora'));
    expect(legal, contains('Vehículo'));
  });

  test(
    'el ticket imprime todos los fundamentos unificados sin duplicarlos',
    () {
      const primero = ConduceLegalidadFundamento(
        id: 31,
        nombre: 'Aliento alcohólico',
        articulo: '345',
        puntos: 0,
        retencionVehiculo: false,
        narrativaSugerida: 'Se detecta aliento alcohólico.',
      );
      const segundo = ConduceLegalidadFundamento(
        id: 32,
        nombre: 'Estado de ebriedad',
        articulo: '508',
        puntos: 0,
        retencionVehiculo: false,
        narrativaSugerida: 'La prueba confirma estado de ebriedad.',
      );
      const captura = ConduceLegalidadCaptura(
        id: 14,
        operativoId: 11,
        fundamentos: [primero, segundo],
        canEdit: true,
        vehiculos: [],
        personas: [],
      );

      final legal = ConduceLegalidadBoletaLegalText.fundamentoInfraccion(
        captura,
        null,
        null,
      );
      final conducta = ConduceLegalidadBoletaLegalText.conducta(
        captura,
        null,
        null,
      );

      expect(legal, contains('Fundamento 1'));
      expect(legal, contains('Artículo 345'));
      expect(legal, contains('Fundamento 2'));
      expect(legal, contains('Artículo 508'));
      expect('Artículo 345'.allMatches(legal), hasLength(1));
      expect(conducta, contains('Se detecta aliento alcohólico.'));
      expect(conducta, contains('La prueba confirma estado de ebriedad.'));
    },
  );
}

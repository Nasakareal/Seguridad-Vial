import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';

void main() {
  test(
    'person physical description fields round trip outside observations',
    () {
      const persona = ConduceLegalidadPersona(
        nombre: 'Persona detenida',
        edad: 30,
        nacionalidad: 'Mexico',
        edadAproximada: '25 a 34 anos',
        complexion: 'Media',
        estatura: 'Alta',
        tez: 'Morena',
        cabello: 'Corto',
        prendaSuperior: 'Playera',
        colorSuperior: 'Negro',
        prendaInferior: 'Pantalon de mezclilla',
        colorInferior: 'Azul',
        calzado: 'Tenis',
        colorCalzado: 'Blanco',
        rasgosVisibles: <String>['Barba', 'Tatuajes'],
      );

      final json = persona.toJson();

      expect(json['observaciones'], isNull);
      expect(json['nacionalidad'], 'Mexico');
      expect(json['edad_aproximada'], '25 a 34 anos');
      expect(json['prenda_superior'], 'Playera');
      expect(json['rasgos_visibles'], <String>['Barba', 'Tatuajes']);

      final restored = ConduceLegalidadPersona.fromJson(json);
      expect(restored.nacionalidad, 'Mexico');
      expect(restored.hasDescripcionFisica, isTrue);
      expect(restored.colorCalzado, 'Blanco');
      expect(restored.rasgosVisibles, <String>['Barba', 'Tatuajes']);
    },
  );

  test('operative parses colonia separately from lugar', () {
    final operativo = ConduceLegalidadOperativo.fromJson({
      'id': 7,
      'nombre': 'Operativo conduce con legalidad',
      'municipio': 'Morelia',
      'lugar': 'Av. Camelinas y Ventura Puente',
      'colonia': 'Felix Ireta',
      'lat': 19.6861,
      'lng': -101.1974,
      'estado': 'activo',
    });

    expect(operativo.lugar, 'Av. Camelinas y Ventura Puente');
    expect(operativo.colonia, 'Felix Ireta');
  });

  test('meta excludes only non operative fundamentos for Conduce Legalidad', () {
    final meta = ConduceLegalidadMeta.fromJson({
      'data': {
        'operativo_nombre': 'Operativo conduce con legalidad',
        'abilities': {'can_feed': true},
        'fundamentos_corralon': [
          {
            'id': 10,
            'codigo': 'OP_CL_SIN_LICENCIA_SIN_HABILITADO',
            'nombre': 'Persona sin licencia y sin persona habilitada inmediata',
            'retencion_vehiculo': true,
            'narrativa_sugerida': 'Narrativa juridica sugerida.',
          },
          {
            'id': 1,
            'codigo': 'ART328_FII_LICENCIA_SUSPENDIDA_CANCELADA',
            'nombre': 'Licencia suspendida o cancelada',
            'retencion_vehiculo': true,
          },
          {
            'id': 2,
            'codigo': 'ART420_FIII_IC_D_MOTO_PASAJERO_MENOR',
            'nombre': 'Motocicleta con pasajero menor',
            'retencion_vehiculo': true,
          },
          {
            'id': 3,
            'codigo': 'ART440_FII_MOTO_VIA_CICLISTA',
            'nombre': 'Motocicleta circula por vias exclusivas para ciclistas',
            'retencion_vehiculo': true,
          },
          {
            'id': 4,
            'codigo': 'ART465_FII_SIRENAS_TORRETAS',
            'nombre': 'Instalar o utilizar sirenas, torretas o estrobos',
            'retencion_vehiculo': true,
          },
          {
            'id': 5,
            'codigo': 'ART654_FII_PLACAS_ROBADAS',
            'nombre': 'Vehiculo porta placas reportadas como robadas',
            'retencion_vehiculo': true,
          },
          {
            'id': 6,
            'codigo': 'ART465_FXI_POLARIZADO_MAYOR_20',
            'nombre': 'Polarizado mayor al veinte por ciento',
            'retencion_vehiculo': true,
          },
          {
            'id': 7,
            'codigo': 'ART420_FIV_IA_B_TRANSPORTE_PUBLICO_ESCOLAR',
            'nombre': 'Transporte publico, escolar o de personal',
            'retencion_vehiculo': true,
          },
          {
            'id': 8,
            'codigo': 'ART519_FIV_IA_NO_MOVER_SINIESTRO_DANOS',
            'nombre':
                'No mover vehiculos cuando el siniestro solo ocasiona danos',
            'retencion_vehiculo': true,
          },
          {
            'id': 9,
            'codigo': 'ART465_FVII_ESCAPE_RUIDO',
            'nombre':
                'Modificar sistema de escape para provocar ruido excesivo',
            'retencion_vehiculo': false,
          },
          {
            'id': 11,
            'codigo': 'ART444_COMPETENCIAS_VELOCIDAD',
            'nombre': 'Participar en competencias de velocidad',
            'retencion_vehiculo': true,
          },
          {
            'id': 12,
            'codigo': 'ART654_PLACAS_DEMOSTRACION',
            'nombre': 'Uso indebido de placas de demostracion',
            'retencion_vehiculo': true,
          },
          {
            'id': 13,
            'codigo': 'ART654_FORANEAS_SIN_REV',
            'nombre': 'Vehiculo con placas foraneas sin registro previo en REV',
            'retencion_vehiculo': true,
          },
          {
            'id': 14,
            'codigo': 'ART654_REGISTRO_VISITA_VENCIDO',
            'nombre': 'Circular con registro de visita vencido',
            'retencion_vehiculo': true,
          },
          {
            'id': 15,
            'codigo': 'ART436_ESTACIONARSE_CARRIL',
            'nombre': 'Estacionarse o reparar vehiculo en carril confinado',
            'retencion_vehiculo': true,
          },
          {
            'id': 16,
            'codigo': 'ART641_REPARACIONES_VIA_PUBLICA',
            'nombre': 'Efectuar reparaciones a vehiculos fuera de emergencia',
            'retencion_vehiculo': true,
          },
          {
            'id': 17,
            'codigo': 'ART641_RESERVAR_ESTACIONAMIENTO',
            'nombre':
                'Colocar objetos o senalizacion para reservar estacionamiento sin autorizacion',
            'retencion_vehiculo': true,
          },
          {
            'id': 18,
            'codigo': 'ART641_CERRAR_OBSTRUIR_CIRCULACION',
            'nombre': 'Cerrar u obstruir circulacion sin autorizacion',
            'retencion_vehiculo': true,
          },
          {
            'id': 19,
            'codigo': 'ART641_NO_RETIRAR_VEHICULO_OBRAS',
            'nombre':
                'Mantener vehiculo estacionado tras requerimiento de retiro por obras o servicios',
            'retencion_vehiculo': true,
          },
          {
            'id': 21,
            'codigo': 'ART648_ASCENSO_DESCENSO_TIEMPO_EXCEDIDO',
            'nombre':
                'Exceder tiempo en espacios especiales de ascenso y descenso',
            'retencion_vehiculo': true,
          },
        ],
      },
    });

    expect(
      meta.fundamentosCorralon.map((item) => item.codigo),
      containsAllInOrder([
        'OP_CL_SIN_LICENCIA_SIN_HABILITADO',
        'ART328_FII_LICENCIA_SUSPENDIDA_CANCELADA',
        'ART420_FIII_IC_D_MOTO_PASAJERO_MENOR',
        'ART440_FII_MOTO_VIA_CICLISTA',
        'ART465_FII_SIRENAS_TORRETAS',
        'ART654_FII_PLACAS_ROBADAS',
      ]),
    );
    expect(meta.fundamentosCorralon, hasLength(6));
    final codigos = meta.fundamentosCorralon.map((item) => item.codigo);
    expect(codigos, isNot(contains('ART444_COMPETENCIAS_VELOCIDAD')));
    expect(codigos, isNot(contains('ART654_PLACAS_DEMOSTRACION')));
    expect(codigos, isNot(contains('ART654_FORANEAS_SIN_REV')));
    expect(codigos, isNot(contains('ART654_REGISTRO_VISITA_VENCIDO')));
    expect(codigos, isNot(contains('ART436_ESTACIONARSE_CARRIL')));
    expect(codigos, isNot(contains('ART641_REPARACIONES_VIA_PUBLICA')));
    expect(codigos, isNot(contains('ART641_RESERVAR_ESTACIONAMIENTO')));
    expect(codigos, isNot(contains('ART641_CERRAR_OBSTRUIR_CIRCULACION')));
    expect(codigos, isNot(contains('ART641_NO_RETIRAR_VEHICULO_OBRAS')));
    expect(codigos, isNot(contains('ART648_ASCENSO_DESCENSO_TIEMPO_EXCEDIDO')));
    expect(
      meta.fundamentosCorralon.first.narrativaSugerida,
      'Narrativa juridica sugerida.',
    );
  });

  test('meta separates combined motorcycle helmet and minor fundamentos', () {
    final meta = ConduceLegalidadMeta.fromJson({
      'data': {
        'operativo_nombre': 'Operativo conduce con legalidad',
        'abilities': {'can_feed': true},
        'fundamentos_corralon': [
          {
            'id': 20,
            'codigo': 'ART420_MOTO_CASCO_MENOR',
            'nombre': 'Motocicleta sin casco y con pasajero menor',
            'texto_operativo': 'Motocicleta sin casco y con pasajero menor',
            'referencia_legal_corta': 'Art. 420',
            'retencion_vehiculo': true,
            'ambito_vehiculo': 'motocicleta',
            'resumen_sanciones': 'deposito',
          },
        ],
      },
    });

    expect(
      meta.fundamentosCorralon.map((item) => item.display),
      containsAllInOrder([
        'Motocicleta sin casco protector',
        'Motocicleta con pasajero menor de edad',
      ]),
    );
    expect(meta.fundamentosCorralon, hasLength(2));
    expect(meta.fundamentosCorralon.map((item) => item.id).toSet(), {20});
  });

  test('meta separates combined motorcycle capacity and helmet fundamentos', () {
    final meta = ConduceLegalidadMeta.fromJson({
      'data': {
        'operativo_nombre': 'Operativo conduce con legalidad',
        'abilities': {'can_feed': true},
        'fundamentos_corralon': [
          {
            'id': 21,
            'codigo': 'ART419_FII_IB_D_MOTO_PASAJEROS_CASCO_DECRETO',
            'nombre':
                'Motocicleta con exceso de personas o incumplimiento grave de casco',
            'texto_operativo':
                'Motocicleta con exceso de personas o incumplimiento grave de casco',
            'referencia_legal_corta': 'Art. 419, fracc. II, inciso b,d',
            'retencion_vehiculo': true,
            'ambito_vehiculo': 'motocicleta',
            'arresto_persona': true,
            'puntos': 3,
            'resumen_sanciones': 'arresto + 3 puntos + deposito',
          },
        ],
      },
    });

    expect(
      meta.fundamentosCorralon.map((item) => item.display),
      containsAllInOrder([
        'Motocicleta con exceso de personas',
        'Motocicleta sin casco protector',
      ]),
    );
    expect(meta.fundamentosCorralon, hasLength(2));
  });

  test('meta corrects combined motorcycle lights and helmet fundamento', () {
    final meta = ConduceLegalidadMeta.fromJson({
      'data': {
        'operativo_nombre': 'Operativo conduce con legalidad',
        'abilities': {'can_feed': true},
        'fundamentos_persona': [
          {
            'id': 22,
            'codigo': 'ART419_FII_IA_C_MOTO_LUCES_CASCO_DECRETO',
            'nombre':
                'Motocicleta sin luces encendidas o sin casco conforme a especificaciones',
            'texto_operativo':
                'Motocicleta sin luces encendidas o sin casco conforme a especificaciones',
            'referencia_legal_corta': 'Art. 419, fracc. II, inciso a,c',
            'retencion_vehiculo': false,
            'ambito_vehiculo': 'motocicleta',
            'amonestacion': true,
            'puntos': 1,
            'resumen_sanciones': 'amonestacion + 1 punto',
          },
        ],
      },
    });

    expect(
      meta.fundamentosPersona.map((item) => item.display),
      containsAllInOrder([
        'Motocicleta sin luces encendidas',
        'Motocicleta sin aditamentos luminosos o bandas reflejantes',
      ]),
    );
    expect(
      meta.fundamentosPersona.any(
        (item) => item.display.toLowerCase().contains('casco'),
      ),
      isFalse,
    );
  });

  test(
    'vehicle restores separated motorcycle fundamento from saved motive',
    () {
      final vehiculo = ConduceLegalidadVehiculo.fromJson({
        'marca': 'ITALIKA',
        'linea': '150',
        'motivo_retencion': 'Art. 420 - Motocicleta con pasajero menor de edad',
        'retencion_vehiculo': true,
        'infraccion': {
          'id': 20,
          'codigo': 'ART420_MOTO_CASCO_MENOR',
          'nombre': 'Motocicleta sin casco y con pasajero menor',
          'texto_operativo': 'Motocicleta sin casco y con pasajero menor',
          'referencia_legal_corta': 'Art. 420',
          'retencion_vehiculo': true,
          'ambito_vehiculo': 'motocicleta',
        },
      });

      expect(
        vehiculo.infraccion?.display,
        'Motocicleta con pasajero menor de edad',
      );
    },
  );

  test('fundamento json keeps enough data for local draft restore', () {
    const fundamento = ConduceLegalidadFundamento(
      id: 30,
      codigo: 'ART419_FII_ID_MOTO_CASCO_DECRETO',
      nombre: 'Motocicleta sin casco protector',
      referenciaLegalCorta: 'Art. 419',
      puntos: 3,
      arrestoPersona: true,
      retencionVehiculo: true,
      resumenSanciones: 'arresto + 3 puntos + deposito',
      fundamentoLegal: 'Articulo 419, fraccion II, inciso d',
      narrativaSugerida: 'Se detecta motocicleta sin casco protector.',
    );

    final restored = ConduceLegalidadFundamento.fromJson(fundamento.toJson());

    expect(restored.id, 30);
    expect(restored.codigo, 'ART419_FII_ID_MOTO_CASCO_DECRETO');
    expect(restored.display, 'Motocicleta sin casco protector');
    expect(restored.sancionResumen, 'arresto + 3 puntos + deposito');
    expect(restored.fundamentoLegal, contains('419'));
    expect(restored.narrativaSugerida, contains('motocicleta'));
  });
}

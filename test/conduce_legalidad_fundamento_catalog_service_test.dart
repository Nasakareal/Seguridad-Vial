import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';
import 'package:seguridad_vial_app/services/conduce_legalidad_fundamento_catalog_service.dart';

void main() {
  const casco = ConduceLegalidadFundamento(
    id: 1,
    codigo: 'ART419_MOTO_CASCO',
    nombre: 'Motocicleta sin casco protector',
    puntos: 3,
    retencionVehiculo: true,
  );
  const menorConduciendo = ConduceLegalidadFundamento(
    id: 2,
    codigo: 'PARTICULAR_MENOR_SIN_PERMISO',
    nombre: 'Menor de edad sin permiso vigente o conduciendo motocicleta',
    puntos: 0,
    retencionVehiculo: true,
  );
  const menorDoce = ConduceLegalidadFundamento(
    id: 3,
    codigo: 'MOTO_MENOR_DOCE',
    nombre: 'Motocicleta transporta menor de doce años',
    puntos: 6,
    retencionVehiculo: true,
  );
  const sinLicencia = ConduceLegalidadFundamento(
    id: 4,
    codigo: 'OP_CL_SIN_LICENCIA_SIN_HABILITADO',
    nombre: 'Persona sin licencia y sin persona habilitada inmediata',
    puntos: 0,
    retencionVehiculo: true,
  );
  const suspendida = ConduceLegalidadFundamento(
    id: 5,
    codigo: 'ART328_FII_LICENCIA_SUSPENDIDA_CANCELADA',
    nombre: 'Licencia suspendida o cancelada',
    puntos: 0,
    retencionVehiculo: true,
  );
  const tarjeta = ConduceLegalidadFundamento(
    id: 6,
    codigo: 'ART328_SIN_TARJETA',
    nombre: 'Sin tarjeta de circulación',
    puntos: 0,
    retencionVehiculo: true,
  );

  test('el primer fundamento solo ofrece causas visibles', () {
    final result = ConduceLegalidadFundamentoCatalogService.causasVisibles(
      const [suspendida, menorDoce, sinLicencia, casco, menorConduciendo],
    );

    expect(result, hasLength(3));
    expect(result.first, casco);
    expect(result[1].display, 'Persona menor de edad conduciendo motocicleta');
    expect(result.last, menorDoce);
  });

  test('los adicionales agrupan licencia y dejan suspendida hasta abajo', () {
    final result =
        ConduceLegalidadFundamentoCatalogService.fundamentosAdicionales(const [
          suspendida,
          tarjeta,
          casco,
          sinLicencia,
        ]);

    expect(result.first, sinLicencia);
    expect(result.last, suspendida);
    expect(
      ConduceLegalidadFundamentoCatalogService.grupo(sinLicencia),
      ConduceLegalidadFundamentoCatalogService.grupoLicencia,
    );
    expect(
      ConduceLegalidadFundamentoCatalogService.grupo(tarjeta),
      ConduceLegalidadFundamentoCatalogService.grupoDocumentos,
    );
  });

  test(
    'solo licencia suspendida va al final y la sancion no contamina grupos',
    () {
      const cascoConSuspension = ConduceLegalidadFundamento(
        id: 60,
        codigo: 'ART419_FII_I_MOTO_CASCO_PROTECTOR',
        nombre: 'Motocicleta sin casco protector',
        fundamentoLegal:
            'Sanción: seis puntos y suspensión de la licencia para conducir.',
        puntos: 6,
        suspensionLicencia: true,
        retencionVehiculo: true,
      );

      final result =
          ConduceLegalidadFundamentoCatalogService.fundamentosAdicionales(
            const [suspendida, cascoConSuspension, sinLicencia],
          );

      expect(result.first, sinLicencia);
      expect(result.last, suspendida);
      expect(
        ConduceLegalidadFundamentoCatalogService.grupo(cascoConSuspension),
        ConduceLegalidadFundamentoCatalogService.grupoVisibles,
      );
    },
  );

  test('no confunde articulo 420 con menor conduciendo del articulo 421', () {
    const menorDoce420 = ConduceLegalidadFundamento(
      id: 61,
      codigo: 'ART420_FIII_I_MOTO_MENOR_DOCE',
      nombre: 'Motocicleta transporta menor de doce años',
      articulo: '420',
      ambitoVehiculo: 'motocicleta',
      puntos: 6,
      retencionVehiculo: true,
    );
    const compuesto421 = ConduceLegalidadFundamento(
      id: 62,
      codigo: 'OP_CL_MENOR_CONDUCIENDO_SIN_HABILITADO',
      nombre:
          'Persona menor de edad conduciendo motocicleta y sin persona habilitada inmediata',
      articulo: '421; 700; 702',
      ambitoVehiculo: 'motocicleta',
      puntos: 3,
      retencionVehiculo: true,
    );

    final result = ConduceLegalidadFundamentoCatalogService.causasVisibles(
      const [menorDoce420, compuesto421],
    );

    expect(result, hasLength(2));
    expect(
      result.map((item) => item.display),
      containsAll(<String>[
        'Motocicleta transporta menor de doce años',
        'Persona menor de edad conduciendo motocicleta',
      ]),
    );
  });

  test('el compuesto de menor permite resguardo y conserva su narrativa', () {
    const compuestoMenor = ConduceLegalidadFundamento(
      id: 63,
      codigo: 'OP_CL_MENOR_CONDUCIENDO_SIN_HABILITADO',
      nombre:
          'Persona menor de edad conduciendo motocicleta y sin persona habilitada inmediata',
      articulo: '421; 700; 702',
      ambitoVehiculo: 'motocicleta',
      puntos: 3,
      amonestacion: true,
      depositoSiSinPersonaHabilitada: true,
      retencionVehiculo: false,
      narrativaSugerida: 'Narrativa compuesta para el retiro.',
    );

    final result = ConduceLegalidadFundamentoCatalogService.causasVisibles(
      const [compuestoMenor],
    );

    expect(result, hasLength(1));
    expect(
      result.single.display,
      'Persona menor de edad conduciendo motocicleta',
    );
    expect(
      result.single.narrativaSugerida,
      'Narrativa compuesta para el retiro.',
    );
    expect(result.single.depositoSiSinPersonaHabilitada, isTrue);
    expect(
      ConduceLegalidadFundamentoCatalogService.seleccionAmeritaResguardo(
        result,
      ),
      isTrue,
    );
  });

  test('incluye luces y ruido, pero excluye puente peatonal y automovil', () {
    const puente = ConduceLegalidadFundamento(
      id: 7,
      codigo: 'ART440_FIV_MOTO_PUENTE_PEATONAL',
      nombre: 'Motocicleta circula sobre puentes peatonales',
      ambitoVehiculo: 'motocicleta',
      puntos: 4,
      retencionVehiculo: false,
    );
    const ruido = ConduceLegalidadFundamento(
      id: 8,
      codigo: 'ART465_FVII_ESCAPE_RUIDO',
      nombre: 'Modificar sistema de escape para provocar ruido excesivo',
      ambitoVehiculo: 'general',
      puntos: 3,
      retencionVehiculo: false,
    );
    const luces = ConduceLegalidadFundamento(
      id: 9,
      codigo: 'ART419_FII_IA_MOTO_LUCES_ENCENDIDAS',
      nombre: 'Motocicleta sin luces delanteras y traseras encendidas',
      ambitoVehiculo: 'motocicleta',
      puntos: 1,
      retencionVehiculo: false,
    );
    const automovilAcera = ConduceLegalidadFundamento(
      id: 10,
      codigo: 'ART436_CONDUCTOR_ACERAS',
      nombre: 'Conductor de automovil circula sobre aceras',
      ambitoVehiculo: 'automovil',
      puntos: 3,
      retencionVehiculo: true,
    );

    final result = ConduceLegalidadFundamentoCatalogService.causasVisibles(
      const [automovilAcera, puente, ruido, luces],
    );

    expect(result, containsAll(<ConduceLegalidadFundamento>[ruido, luces]));
    expect(result, isNot(contains(puente)));
    expect(result, isNot(contains(automovilAcera)));
  });

  test('presenta claramente al menor conduciendo motocicleta', () {
    final result = ConduceLegalidadFundamentoCatalogService.causasVisibles(
      const [menorConduciendo],
    );

    expect(result, hasLength(1));
    expect(
      result.single.display,
      'Persona menor de edad conduciendo motocicleta',
    );
    expect(
      result.single.narrativaSugerida,
      'Se detecta a una persona menor de edad conduciendo una motocicleta.',
    );
  });

  test('exige retencion, deposito o arresto para justificar resguardo', () {
    const luces = ConduceLegalidadFundamento(
      id: 20,
      nombre: 'Motocicleta sin luces encendidas',
      puntos: 1,
      retencionVehiculo: false,
    );
    const puenteConArresto = ConduceLegalidadFundamento(
      id: 21,
      nombre: 'Moto circula por carriles centrales o puentes',
      puntos: 3,
      arrestoPersona: true,
      retencionVehiculo: false,
    );

    expect(
      ConduceLegalidadFundamentoCatalogService.seleccionAmeritaResguardo([
        luces,
      ]),
      isFalse,
    );
    expect(
      ConduceLegalidadFundamentoCatalogService.seleccionAmeritaResguardo([
        luces,
        puenteConArresto,
      ]),
      isTrue,
    );
    expect(
      ConduceLegalidadFundamentoCatalogService.resguardoRequeridoMensaje,
      contains('retención, depósito o arresto'),
    );
  });

  test('oculta fundamentos retirados y conserva portar licencia', () {
    const codigosExcluidos = <String>[
      'ART402_LICENCIA_FORANEA_REINCIDENCIA',
      'ART432_FVII_REBASAR_IZQUIERDA_SEPARACION',
      'ART432_FVIII_ALINEARSE_DERECHA',
      'ART432_FIX_DISTANCIA_RAZONABLE',
      'ART432_FX_DIRECCIONALES',
      'ART432_FXI_PERMITIR_INCORPORACION',
      'ART432_FXII_CEDER_SERVICIO_SOCIAL',
      'ART432_FXV_VIAS_FERREAS',
      'ART432_FXVI_ASCENSO_CARRIL_ACERA',
      'ART432_FXVII_PORTAR_REGLAMENTO',
      'ART432_FXIX_CARAVANA_ESPACIO',
      'ART437_SERVICIO_SOCIAL_USO_INDEBIDO_SENALES',
      'ART439_FII_MOTO_REBASE_IZQUIERDA',
      'ART459_FII_I_MOTORIZADO_CINTURONES_SEGURIDAD',
      'ART459_FII_I_MOTORIZADO_LIMPIAPARABRISAS',
      'ART459_FII_I_MOTORIZADO_HERRAMIENTA_LLANTAS',
    ];
    final excluidos = codigosExcluidos.indexed
        .map(
          (entry) => ConduceLegalidadFundamento(
            id: 100 + entry.$1,
            codigo: entry.$2,
            nombre: entry.$2,
            puntos: 0,
            retencionVehiculo: true,
          ),
        )
        .toList();
    const portarLicencia = ConduceLegalidadFundamento(
      id: 208,
      codigo: 'ART432_FI_PORTAR_LICENCIA',
      nombre: 'No portar licencia correspondiente',
      puntos: 0,
      retencionVehiculo: true,
    );

    final result =
        ConduceLegalidadFundamentoCatalogService.fundamentosAdicionales([
          ...excluidos,
          portarLicencia,
        ]);

    expect(result, [portarLicencia]);
  });
}

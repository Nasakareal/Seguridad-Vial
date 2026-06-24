import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/licencia_puntos_service.dart';

void main() {
  test('generates scoped idempotency keys for point movements', () {
    final first = LicenciaPuntosService.createIdempotencyKey(
      'Licencia Descuento',
    );
    final second = LicenciaPuntosService.createIdempotencyKey(
      'Licencia Descuento',
    );

    expect(first, startsWith('licencia-descuento-'));
    expect(second, startsWith('licencia-descuento-'));
    expect(first, isNot(second));
  });

  test('generates readable automatic movement folios', () {
    final folio = LicenciaPuntosService.createMovimientoFolio('LPD');

    expect(folio, matches(RegExp(r'^LPD-\d{8}-\d{6}-[A-F0-9]{6}$')));
  });

  test('parses legal basis from catalog and movement payloads', () {
    const fundamento =
        'Fundamentado en el Reglamento de la Ley de Movilidad y Seguridad Vial vigente en el Estado.';

    final meta = LicenciaPuntosMeta.fromJson(<String, dynamic>{
      'saldo_inicial': 12,
      'saldo_maximo': 12,
      'meses_recuperacion_tiempo': 18,
      'abilities': <String, dynamic>{},
      'tipos_licencia': <String, dynamic>{
        'AUTOMOVILISTA': 'Automovilista',
        'CHOFER': 'Chofer',
      },
      'infracciones': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'codigo': 'CELULAR',
          'nombre': 'Celular al conducir',
          'puntos': 1,
          'descripcion': '',
          'fundamento_legal': fundamento,
        },
      ],
    });

    expect(meta.infracciones.single.fundamentoLegal, fundamento);
    expect(meta.tiposLicencia['CHOFER'], 'Chofer');

    final movimiento = LicenciaPuntoMovimiento.fromJson(<String, dynamic>{
      'tipo': 'infraccion',
      'puntos': -1,
      'saldo_anterior': 8,
      'saldo_nuevo': 7,
      'fecha_movimiento': '2026-06-17T11:30:00-06:00',
      'referencia': '',
      'descripcion': '',
      'infraccion': <String, dynamic>{
        'nombre': 'Celular al conducir',
        'fundamento_legal': fundamento,
      },
    });

    expect(movimiento.infraccionNombre, 'Celular al conducir');
    expect(movimiento.infraccionFundamentoLegal, fundamento);
  });

  test('normalizes license type aliases and labels account payloads', () {
    expect(
      LicenciaTipoCatalog.normalize('Servicio público'),
      'SERVICIO_PUBLICO',
    );
    expect(LicenciaTipoCatalog.normalize('Particular'), 'AUTOMOVILISTA');
    expect(LicenciaTipoCatalog.normalize('Operador'), 'CHOFER');
    expect(LicenciaTipoCatalog.normalize('C'), 'MOTOCICLISTA');
    expect(LicenciaTipoCatalog.normalize('tipo inventado'), isNull);

    final cuenta = LicenciaPuntoCuenta.fromJson(<String, dynamic>{
      'id': 1,
      'numero_licencia': 'MICHOACAN12345',
      'tipo_licencia': 'AUTOMOVILISTA',
      'titular_nombre': 'JUAN PEREZ LOPEZ',
      'curp': '',
      'telefono': '',
      'saldo_actual': 12,
      'saldo_maximo': 12,
      'nivel_saldo': 'normal',
      'estado': 'vigente',
      'estado_label': 'Vigente',
      'fecha_recuperacion': '',
      'cuenta_registrada': true,
      'movimientos': <Map<String, dynamic>>[],
      'alertas': <Map<String, dynamic>>[],
    });

    expect(cuenta.tipoLicencia, 'AUTOMOVILISTA');
    expect(cuenta.tipoLicenciaLabel, 'Automovilista');
  });
}

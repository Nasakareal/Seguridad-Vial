import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/core/hechos/hechos_catalogos.dart';
import 'package:seguridad_vial_app/models/hecho_form_data.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:seguridad_vial_app/services/hechos_form_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  HechoFormData validDelegacionesData({String vehiculosEsperados = '1'}) {
    return HechoFormData()
      ..perito = 'Elemento de prueba'
      ..unidad = 'Unidad 01'
      ..hora = const TimeOfDay(hour: 9, minute: 30)
      ..fecha = DateTime(2026, 4, 25)
      ..calle = 'Lugar de prueba'
      ..colonia = 'Centro'
      ..municipio = 'Morelia'
      ..tipoHecho = HechosCatalogos.tiposHecho.first
      ..superficieVia = HechosCatalogos.superficiesViaUi.first
      ..tiempo = HechosCatalogos.tiemposUi.first
      ..clima = HechosCatalogos.climasUi.first
      ..condiciones = HechosCatalogos.condicionesUi.first
      ..controlTransito = HechosCatalogos.controlesTransitoUi.last
      ..causa = HechosCatalogos.causasUi.first
      ..responsable = HechosCatalogos.responsablesUi.first
      ..colisionCamino = HechosCatalogos.colisionCaminoUi.first
      ..situacion = 'TURNADO'
      ..vehiculosMp = '1'
      ..personasMp = '0'
      ..vehiculosEsperados = vehiculosEsperados
      ..conductoresEsperados = vehiculosEsperados == '0' ? '0' : '1'
      ..lesionadosEsperados = '0'
      ..lat = 19.7
      ..lng = -101.2;
  }

  test('delegaciones can turnado a hecho without dictamen', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_role': 'Policia',
    });

    final data = validDelegacionesData();

    final error = await HechosFormService.validateBeforeSubmit(
      data: data,
      dictamenSelected: null,
    );

    expect(error, isNull);
  });

  test('delegaciones turnado payload can link a puesta disposicion', () {
    final data = validDelegacionesData()..puestaDisposicionId = 42;

    final fields = HechosFormService.buildFieldsForTesting(
      data,
      null,
      usesRelaxedHechosRules: true,
      canUseDictamenes: false,
      canUsePuestasDisposicion: true,
      canCaptureMpTurnado: true,
    );

    expect(fields['puesta_disposicion_id'], '42');
    expect(fields.containsKey('dictamen_id'), isFalse);
  });

  test('siniestros payload does not send puesta disposicion link', () {
    final data = validDelegacionesData()..puestaDisposicionId = 42;

    final fields = HechosFormService.buildFieldsForTesting(
      data,
      null,
      usesRelaxedHechosRules: true,
      canUseDictamenes: true,
      canUsePuestasDisposicion: false,
      canCaptureMpTurnado: true,
    );

    expect(fields.containsKey('puesta_disposicion_id'), isFalse);
  });

  test('delegaciones turnado still requires expected vehicle count', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_role': 'Policia',
    });

    final error = await HechosFormService.validateBeforeSubmit(
      data: validDelegacionesData(vehiculosEsperados: '0'),
      dictamenSelected: null,
    );

    expect(
      error,
      'Cuando el hecho está TURNADO, debe capturarse al menos 1 vehículo.',
    );
  });

  test('delegaciones turnado requires MP vehicle count', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_role': 'Policia',
    });

    final data = validDelegacionesData()..vehiculosMp = '0';

    final error = await HechosFormService.validateBeforeSubmit(
      data: data,
      dictamenSelected: null,
    );

    expect(
      error,
      'Cuando el hecho está TURNADO, Vehículos MP debe ser mayor que cero.',
    );
  });

  test('delegaciones pending does not require MP counts', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_role': 'Policia',
    });

    final data = validDelegacionesData(vehiculosEsperados: '0')
      ..situacion = 'PENDIENTE'
      ..vehiculosMp = ''
      ..personasMp = '';

    final error = await HechosFormService.validateBeforeSubmit(
      data: data,
      dictamenSelected: null,
    );

    expect(error, isNull);
  });

  test(
    'delegaciones pending keeps expected totals validation separate',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_unidad_id': AuthService.unidadDelegacionesId,
        'auth_role': 'Policia',
      });

      final data = validDelegacionesData()
        ..situacion = 'PENDIENTE'
        ..vehiculosMp = ''
        ..personasMp = ''
        ..vehiculosEsperados = ''
        ..conductoresEsperados = '0'
        ..lesionadosEsperados = '0';

      final error = await HechosFormService.validateBeforeSubmit(
        data: data,
        dictamenSelected: null,
      );

      expect(error, 'Indica cuántos vehículos participaron.');
    },
  );

  test(
    'delegaciones privileged users still do not need dictamen for turnado',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_unidad_id': AuthService.unidadDelegacionesId,
        'auth_role': 'Superadmin',
      });

      final error = await HechosFormService.validateBeforeSubmit(
        data: validDelegacionesData(),
        dictamenSelected: null,
      );

      expect(error, isNull);
    },
  );

  test('hecho capture rejects unknown municipality text', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_role': 'Policia',
    });

    final data = validDelegacionesData()..municipio = 'mirilia';

    final error = await HechosFormService.validateBeforeSubmit(
      data: data,
      dictamenSelected: null,
    );

    expect(error, 'Selecciona un municipio de Michoacan.');
  });
}

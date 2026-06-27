import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';

void main() {
  test(
    'meta excludes only non operative fundamentos for Conduce Legalidad',
    () {
      final meta = ConduceLegalidadMeta.fromJson({
        'data': {
          'operativo_nombre': 'Operativo conduce con legalidad',
          'abilities': {'can_feed': true},
          'fundamentos_corralon': [
            {
              'id': 10,
              'codigo': 'OP_CL_SIN_LICENCIA_SIN_HABILITADO',
              'nombre':
                  'Persona sin licencia y sin persona habilitada inmediata',
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
              'nombre':
                  'Motocicleta circula por vias exclusivas para ciclistas',
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
      expect(
        meta.fundamentosCorralon.first.narrativaSugerida,
        'Narrativa juridica sugerida.',
      );
    },
  );
}

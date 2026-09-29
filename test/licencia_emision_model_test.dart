import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/licencia_emision.dart';

void main() {
  test('license parses exam, certificate and variable card data', () {
    final license = LicenciaEmision.fromJson(<String, dynamic>{
      'id': 7,
      'numero': '1120260000007',
      'curp': 'LOCA850516HMNPRS01',
      'apellido_paterno': 'López',
      'apellido_materno': 'Cárdenas',
      'nombres': 'Alberto',
      'nombre_completo': 'Alberto López Cárdenas',
      'fecha_nacimiento': '1985-05-16',
      'fecha_expedicion': '2026-09-28',
      'fecha_vencimiento': '2030-09-28',
      'fecha_antiguedad': '2022-06-25',
      'tipo_licencia': 'B',
      'genero': 'H',
      'tipo_sangre': 'O+',
      'donador_organos': true,
      'restricciones': 'NINGUNA',
      'oficina_emisora': 'POLICÍA Y TRÁNSITO',
      'vehiculos_autorizados': 'VEHÍCULOS DE USO PRIVADO',
      'estatus': 'VIGENTE',
      'constancia': <String, dynamic>{
        'id': 20,
        'folio': 'CM-00020',
        'estatus': 'ACTIVA',
      },
      'examen': <String, dynamic>{
        'id': 11,
        'folio': 'EX-00011',
        'estatus': 'APROBADO',
        'calificacion': '92.5',
      },
    });

    expect(license.numero, '1120260000007');
    expect(license.nombreCompleto, 'Alberto López Cárdenas');
    expect(license.donadorOrganos, isTrue);
    expect(license.constancia?.folio, 'CM-00020');
    expect(license.examen?.folio, 'EX-00011');
    expect(license.examen?.calificacion, 92.5);
  });

  test(
    'license module route and drawer entry are restricted to superadmin',
    () {
      final routes = File('lib/app/router_map.dart').readAsStringSync();
      final drawer = File('lib/widgets/app_drawer.dart').readAsStringSync();

      expect(routes, contains('AppRoutes.herramientasLicenciasEmision'));
      expect(routes, contains('const SuperadminGuard('));
      expect(drawer, contains('if (isSuperadmin)'));
      expect(drawer, contains("label: 'Emisión de licencias'"));
    },
  );
}

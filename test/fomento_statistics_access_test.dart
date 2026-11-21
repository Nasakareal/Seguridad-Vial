import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/estadisticas/estadisticas_reporte_screen.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Instructor',
      'auth_role_id': 9,
      'auth_unidad_id': AuthService.unidadCulturaVialId,
      'auth_user_payload': jsonEncode(<String, Object>{
        'role': <String, Object>{'id': 9, 'name': 'Instructor'},
        'unidad_id': AuthService.unidadCulturaVialId,
      }),
    });
  });

  testWidgets('direct route blocks unauthorized Fomento roles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EstadisticasReporteScreen(
          reporte: 'fomento-servicios-personal',
          titulo: 'Servicios por personal',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('No tienes acceso a las estadísticas de Fomento.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });
}

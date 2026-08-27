import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/actividad.dart';
import 'package:seguridad_vial_app/screens/actividades/actividad_corralon_ticket_screen.dart';

void main() {
  testWidgets('el ticket muestra firma, inconformidad y aviso de Siniestros', (
    tester,
  ) async {
    final actividad = Actividad.fromJson({
      'id': 27,
      'nombre': 'AGENTE DE PRUEBA',
      'creador_unidad_id': 1,
      'fecha': '2026-08-27',
      'hora': '10:30:00',
    });

    await tester.pumpWidget(
      MaterialApp(home: ActividadCorralonTicketScreen(actividad: actividad)),
    );

    expect(find.text('MANIFESTACIÓN DE INCONFORMIDAD'), findsOneWidget);
    expect(find.text('Firma de la persona infractora'), findsOneWidget);
    expect(find.text(actividadCorralonAvisoSiniestros), findsOneWidget);
  });

  testWidgets('el aviso de recuperación no aparece para otra unidad', (
    tester,
  ) async {
    final actividad = Actividad.fromJson({
      'id': 28,
      'nombre': 'AGENTE DE PRUEBA',
      'creador_unidad_id': 2,
    });

    await tester.pumpWidget(
      MaterialApp(home: ActividadCorralonTicketScreen(actividad: actividad)),
    );

    expect(find.text(actividadCorralonAvisoSiniestros), findsNothing);
    expect(find.text('Firma de la persona infractora'), findsOneWidget);
  });
}

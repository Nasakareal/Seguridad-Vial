import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/accidentes/hecho_show/hecho_show_helpers.dart';
import 'package:seguridad_vial_app/widgets/reporte_robo_selector.dart';

void main() {
  test('detecta si al menos un vehículo tiene reporte de robo', () {
    final hecho = <String, dynamic>{
      'unidad_org_id': 2,
      'vehiculos': [
        {'id': 1, 'reporte_robo': 0},
        {'id': 2, 'reporte_robo': '1'},
      ],
    };

    expect(HechoShowHelpers.esHechoDelegaciones(hecho), isTrue);
    expect(HechoShowHelpers.hayVehiculoConReporteRobo(hecho), isTrue);
  });

  testWidgets('selector obliga a elegir sí o no', (tester) async {
    bool? value;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: ReporteRoboSelector(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    expect(value, isNull);
    expect(find.text('Seleccione una opción'), findsOneWidget);
    final selector = find.byKey(const Key('reporte_robo_selector'));
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí').last);
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });
}

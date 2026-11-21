import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/accidentes/widgets/hecho_card.dart';

void main() {
  testWidgets('keeps WhatsApp visible and moves other actions to three dots', (
    tester,
  ) async {
    var selected = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HechoCard(
              hecho: const <String, dynamic>{},
              folio: 'C5-1',
              fecha: '2026-11-20',
              hora: '10:00',
              situacion: 'TURNADO',
              perito: 'Elemento',
              ubicacion: 'Morelia',
              fotoHecho: '',
              fotoHecho2: '',
              fotoSituacion: '',
              fotosVehiculos: const <String>[],
              fotoConvenio: '',
              isDownloading: false,
              isSending: false,
              onTapShow: () => selected = 'show',
              onTapEdit: () => selected = 'edit',
              onDownload: () => selected = 'report',
              onEnviarWhatsapp: () => selected = 'whatsapp',
              additionalMenuActions: <HechoCardMenuAction>[
                HechoCardMenuAction(
                  id: 'iph-puesta',
                  label: 'Generar IPH y puesta (Word)',
                  icon: Icons.description_outlined,
                  onTap: () => selected = 'iph-puesta',
                ),
                HechoCardMenuAction(
                  id: 'dictamen',
                  label: 'Descargar dictamen',
                  icon: Icons.description_outlined,
                  onTap: () => selected = 'dictamen',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Compartir por WhatsApp'), findsOneWidget);
    expect(find.byTooltip('Más opciones'), findsOneWidget);
    expect(find.byTooltip('Descargar informe'), findsNothing);
    expect(find.byTooltip('Editar'), findsNothing);

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();

    expect(find.text('Ver detalles'), findsOneWidget);
    expect(find.text('Descargar informe'), findsOneWidget);
    expect(find.text('Generar IPH y puesta (Word)'), findsOneWidget);
    expect(find.text('Descargar dictamen'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);

    await tester.tap(find.text('Descargar dictamen'));
    await tester.pumpAndSettle();
    expect(selected, 'dictamen');
  });
}

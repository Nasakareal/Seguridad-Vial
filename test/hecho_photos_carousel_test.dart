import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/accidentes/widgets/hecho_photos_carousel.dart';

Widget _host({required String primary, required String secondary}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 420,
        child: HechoPhotosCarousel(
          primaryUrl: primary,
          secondaryUrl: secondary,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('una sola foto se muestra sin carrusel ni controles', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(primary: 'https://example.test/foto-1.jpg', secondary: ''),
    );

    expect(find.text('Foto del hecho'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('1 / 1'), findsNothing);
  });

  testWidgets('dos fotos permiten avanzar y muestran su posición', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        primary: 'https://example.test/foto-1.jpg',
        secondary: 'https://example.test/foto-2.jpg',
      ),
    );

    expect(find.text('Fotos del hecho'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}

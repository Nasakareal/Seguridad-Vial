import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/widgets/drawer_ui.dart';
import 'package:seguridad_vial_app/widgets/glass.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, child: child)),
    );
  }

  testWidgets('muestra el escudo de la unidad como fondo sin icono genérico', (
    tester,
  ) async {
    const assetPath = 'assets/images/pompella/siniestros.png';

    await tester.pumpWidget(
      host(
        const DrawerHeaderPanel(
          title: 'Seguridad Vial',
          subtitle: '',
          backgroundAssetPath: assetPath,
        ),
      ),
    );

    final background = tester.widget<Image>(find.byType(Image));
    expect(background.image, isA<ResizeImage>());
    final resized = background.image as ResizeImage;
    expect(resized.imageProvider, isA<AssetImage>());
    expect((resized.imageProvider as AssetImage).assetName, assetPath);
    expect(background.fit, BoxFit.contain);
    expect(find.byIcon(Icons.shield_outlined), findsNothing);
  });

  testWidgets('permite pulsar la foto de perfil del encabezado', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      host(
        DrawerHeaderPanel(
          title: 'Usuario',
          subtitle: 'usuario@example.com',
          avatarText: 'US',
          photoUrl: 'https://example.invalid/foto.jpg',
          onPhotoTap: () => taps++,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Ver foto de perfil'));

    expect(taps, 1);
  });

  testWidgets('las superficies del drawer no crean blur por tarjeta', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const DrawerSurface(child: SizedBox(width: 200, height: 80))),
    );

    final surface = tester.widget<LiquidGlassSurface>(
      find.byType(LiquidGlassSurface),
    );

    expect(surface.blur, 0);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/feed_item.dart';
import 'package:seguridad_vial_app/screens/home/widgets/feed_post_card.dart';
import 'package:seguridad_vial_app/widgets/glass.dart';
import 'package:seguridad_vial_app/widgets/safe_network_image.dart';

void main() {
  const item = FeedItem(
    type: FeedItemType.actividad,
    id: 1,
    userId: 2,
    userName: 'Operador',
    resumen: 'Publicación de prueba',
    categoriaNombre: null,
    subcategoriaNombre: null,
    fotoUrl: 'https://example.invalid/feed.jpg',
    createdAt: null,
    showUrl: null,
    unidadId: null,
    unidadNombre: null,
    delegacionId: null,
    delegacionNombre: null,
  );

  testWidgets('la tarjeta conserva Liquid Glass sin blur por publicación', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeedPostCard(item: item, onTap: () {}),
          ),
        ),
      ),
    );

    final surface = tester.widget<LiquidGlassSurface>(
      find.byType(LiquidGlassSurface),
    );

    expect(surface.blur, 0);
  });

  testWidgets('la foto limita su tamaño de decodificación', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BigFeedImage(url: 'https://example.invalid/a.jpg'),
        ),
      ),
    );

    final image = tester.widget<SafeNetworkImage>(
      find.byType(SafeNetworkImage),
    );

    expect(image.cacheWidth, isNotNull);
    expect(image.cacheWidth, inInclusiveRange(1, 1080));
  });
}

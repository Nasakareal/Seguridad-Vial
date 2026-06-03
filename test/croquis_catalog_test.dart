import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/core/croquis/croquis_catalog.dart';

void main() {
  test('catalogo movil incluye iconos generales nuevos del croquis web', () {
    final general = CroquisCatalog.iconCategories.firstWhere(
      (category) => category.key == 'general',
    );
    final byKey = {for (final item in general.items) item.key: item};

    expect(
      byKey.keys,
      containsAll(['poste_doble', 'poste_solo', 'street_light']),
    );
    expect(
      byKey['poste_doble']!.src,
      contains('/img/croquis/iconos/Poste_doble.png'),
    );
    expect(
      byKey['poste_solo']!.src,
      contains('/img/croquis/iconos/Poste_solo.png'),
    );
    expect(
      byKey['street_light']!.src,
      contains('/img/croquis/iconos/street-light.png'),
    );
  });
}

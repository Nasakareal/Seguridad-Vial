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

  test('catalogo movil incluye todas las motocicletas del backend', () {
    final motocicletas = CroquisCatalog.vehicleCategories.firstWhere(
      (category) => category.key == 'motocicleta',
    );
    final byFile = <String>{
      for (final item in motocicletas.items)
        Uri.parse(item.src).pathSegments.last,
    };

    expect(
      byFile,
      containsAll(<String>[
        'AdvAc.png',
        'ATV.png',
        'CafeRacerAc.png',
        'CrossAc.png',
        'Cruisier.png',
        'Delivery.png',
        'DeliveryAc.png',
        'DeportivaAc.png',
        'MotoTaxi.png',
        'MotoTaxiAc.png',
        'Patrulla.png',
        'Pista.png',
        'PoliciaAc.png',
        'Sobrecarga.png',
        'Trabajo.png',
        'Volteada.png',
      ]),
    );
    expect(motocicletas.items, hasLength(16));
  });
}

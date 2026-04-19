import '../../services/auth_service.dart';

class CroquisCatalogItem {
  const CroquisCatalogItem({
    required this.key,
    required this.label,
    required this.src,
    this.subtipo,
    this.anchoOriginal,
    this.altoOriginal,
  });

  final String key;
  final String label;
  final String src;
  final String? subtipo;
  final double? anchoOriginal;
  final double? altoOriginal;
}

class CroquisCatalogCategory {
  const CroquisCatalogCategory({
    required this.key,
    required this.label,
    required this.items,
  });

  final String key;
  final String label;
  final List<CroquisCatalogItem> items;
}

class CroquisCatalog {
  static String assetUrl(List<String> segments) {
    final api = Uri.parse(AuthService.baseUrl);
    return Uri(
      scheme: api.scheme,
      host: api.host,
      port: api.hasPort ? api.port : null,
      pathSegments: segments,
    ).toString();
  }

  static CroquisCatalogItem iconItem({
    required String key,
    required String label,
    required List<String> path,
  }) {
    return CroquisCatalogItem(
      key: key,
      label: label,
      src: assetUrl(<String>['img', 'croquis', 'iconos', ...path]),
    );
  }

  static CroquisCatalogItem vehicleItem({
    required String subtipo,
    required String label,
    required String categoria,
    required String file,
    double anchoOriginal = 90,
    double altoOriginal = 90,
  }) {
    return CroquisCatalogItem(
      key: subtipo,
      subtipo: subtipo,
      label: label,
      src: assetUrl(<String>['img', 'croquis', 'vehiculos', categoria, file]),
      anchoOriginal: anchoOriginal,
      altoOriginal: altoOriginal,
    );
  }

  static final CroquisCatalogItem cardinalPoints = iconItem(
    key: 'cardinal_points',
    label: 'Puntos cardinales',
    path: const <String>['cardinal-points.png'],
  );

  static final List<CroquisCatalogCategory>
  iconCategories = <CroquisCatalogCategory>[
    CroquisCatalogCategory(
      key: 'general',
      label: 'General',
      items: <CroquisCatalogItem>[cardinalPoints],
    ),
    CroquisCatalogCategory(
      key: 'semaforos_senalamientos',
      label: 'Semáforos y señalamientos',
      items: <CroquisCatalogItem>[
        iconItem(
          key: 'semaforos_senalamientos_semaforo1',
          label: 'Semáforo 1',
          path: const <String>['semaforos_senalamientos', 'Semafóro1.png'],
        ),
        iconItem(
          key: 'semaforos_senalamientos_semaforo2',
          label: 'Semáforo 2',
          path: const <String>['semaforos_senalamientos', 'Semafóro2.png'],
        ),
        iconItem(
          key: 'semaforos_senalamientos_traffic_cone',
          label: 'Cono',
          path: const <String>['semaforos_senalamientos', 'traffic-cone.png'],
        ),
        iconItem(
          key: 'semaforos_senalamientos_traffic_light',
          label: 'Semáforo',
          path: const <String>['semaforos_senalamientos', 'traffic-light.png'],
        ),
      ],
    ),
    CroquisCatalogCategory(
      key: 'construcciones',
      label: 'Construcciones',
      items: <CroquisCatalogItem>[
        iconItem(
          key: 'construcciones_apartment',
          label: 'Departamento',
          path: const <String>['construcciones', 'apartment.png'],
        ),
        iconItem(
          key: 'construcciones_store',
          label: 'Tienda',
          path: const <String>['construcciones', 'store.png'],
        ),
        iconItem(
          key: 'construcciones_taqueria',
          label: 'Taquería',
          path: const <String>['construcciones', 'Taquería.png'],
        ),
        iconItem(
          key: 'construcciones_warehouse',
          label: 'Bodega',
          path: const <String>['construcciones', 'warehouse.png'],
        ),
      ],
    ),
    CroquisCatalogCategory(
      key: 'flechas_especiales',
      label: 'Flechas e iconos especiales',
      items: <CroquisCatalogItem>[
        iconItem(
          key: 'flechas_especiales_a',
          label: 'A',
          path: const <String>['flechas_especiales', 'A.png'],
        ),
        iconItem(
          key: 'flechas_especiales_b',
          label: 'B',
          path: const <String>['flechas_especiales', 'B.png'],
        ),
        iconItem(
          key: 'flechas_especiales_c',
          label: 'C',
          path: const <String>['flechas_especiales', 'C.png'],
        ),
        iconItem(
          key: 'flechas_especiales_pow',
          label: 'Impacto',
          path: const <String>['flechas_especiales', 'pow.png'],
        ),
      ],
    ),
  ];

  static final List<CroquisCatalogCategory> vehicleCategories =
      <CroquisCatalogCategory>[
        CroquisCatalogCategory(
          key: 'automovil',
          label: 'Automóvil',
          items: <CroquisCatalogItem>[
            vehicleItem(
              categoria: 'automovil',
              subtipo: 'decabeza',
              label: 'De cabeza',
              file: 'decabeza.png',
            ),
            vehicleItem(
              categoria: 'automovil',
              subtipo: 'defrente',
              label: 'De frente',
              file: 'defrente.png',
            ),
            vehicleItem(
              categoria: 'automovil',
              subtipo: 'hatchback_red',
              label: 'Hatchback rojo',
              file: 'Hatchback_Red.png',
              anchoOriginal: 120,
              altoOriginal: 72,
            ),
            vehicleItem(
              categoria: 'automovil',
              subtipo: 'patrol',
              label: 'Patrulla',
              file: 'Patrol.png',
              anchoOriginal: 120,
              altoOriginal: 72,
            ),
            vehicleItem(
              categoria: 'automovil',
              subtipo: 'retroexcavadora',
              label: 'Retroexcavadora',
              file: 'Retroexcavadora.png',
              anchoOriginal: 120,
              altoOriginal: 80,
            ),
            vehicleItem(
              categoria: 'automovil',
              subtipo: 'sedan_grey',
              label: 'Sedán gris',
              file: 'Sedán_Grey.png',
              anchoOriginal: 120,
              altoOriginal: 72,
            ),
            vehicleItem(
              categoria: 'automovil',
              subtipo: 'sedan_red',
              label: 'Sedán rojo',
              file: 'Sedán_Red.png',
              anchoOriginal: 120,
              altoOriginal: 72,
            ),
            vehicleItem(
              categoria: 'automovil',
              subtipo: 'sedan_yellow',
              label: 'Sedán amarillo',
              file: 'Sedán_Yellow.png',
              anchoOriginal: 120,
              altoOriginal: 72,
            ),
            vehicleItem(
              categoria: 'automovil',
              subtipo: 'suv_grey',
              label: 'SUV gris',
              file: 'Suv_Grey.png',
              anchoOriginal: 120,
              altoOriginal: 72,
            ),
            vehicleItem(
              categoria: 'automovil',
              subtipo: 'volteado',
              label: 'Volteado',
              file: 'Volteado.png',
            ),
          ],
        ),
        CroquisCatalogCategory(
          key: 'camion',
          label: 'Camión',
          items: <CroquisCatalogItem>[
            vehicleItem(
              categoria: 'camion',
              subtipo: 'autobus',
              label: 'Autobús',
              file: 'Autobús.png',
              anchoOriginal: 150,
              altoOriginal: 80,
            ),
            vehicleItem(
              categoria: 'camion',
              subtipo: 'camion',
              label: 'Camión',
              file: 'Camión.png',
              anchoOriginal: 150,
              altoOriginal: 80,
            ),
            vehicleItem(
              categoria: 'camion',
              subtipo: 'remolque',
              label: 'Remolque',
              file: 'Remolque.png',
              anchoOriginal: 150,
              altoOriginal: 80,
            ),
            vehicleItem(
              categoria: 'camion',
              subtipo: 'remolquealreves',
              label: 'Remolque al revés',
              file: 'RemolqueAlreves.png',
              anchoOriginal: 150,
              altoOriginal: 80,
            ),
            vehicleItem(
              categoria: 'camion',
              subtipo: 'tracto',
              label: 'Tracto',
              file: 'Tracto.png',
              anchoOriginal: 150,
              altoOriginal: 80,
            ),
            vehicleItem(
              categoria: 'camion',
              subtipo: 'tractoalreves',
              label: 'Tracto al revés',
              file: 'TractoAlreves.png',
              anchoOriginal: 150,
              altoOriginal: 80,
            ),
          ],
        ),
        CroquisCatalogCategory(
          key: 'camioneta',
          label: 'Camioneta',
          items: <CroquisCatalogItem>[
            vehicleItem(
              categoria: 'camioneta',
              subtipo: 'ambulancia',
              label: 'Ambulancia',
              file: 'Ambulancia.png',
              anchoOriginal: 120,
              altoOriginal: 72,
            ),
            vehicleItem(
              categoria: 'camioneta',
              subtipo: 'pickup',
              label: 'Pickup',
              file: 'pickup.png',
              anchoOriginal: 120,
              altoOriginal: 72,
            ),
          ],
        ),
        CroquisCatalogCategory(
          key: 'bicicleta',
          label: 'Bicicleta',
          items: <CroquisCatalogItem>[
            vehicleItem(
              categoria: 'bicicleta',
              subtipo: 'imagen4',
              label: 'Bicicleta 1',
              file: 'Imagen4.png',
            ),
            vehicleItem(
              categoria: 'bicicleta',
              subtipo: 'imagen5',
              label: 'Bicicleta 2',
              file: 'Imagen5.png',
            ),
          ],
        ),
        CroquisCatalogCategory(
          key: 'motocicleta',
          label: 'Motocicleta',
          items: <CroquisCatalogItem>[
            vehicleItem(
              categoria: 'motocicleta',
              subtipo: 'cruisier',
              label: 'Crucero',
              file: 'Cruisier.png',
            ),
            vehicleItem(
              categoria: 'motocicleta',
              subtipo: 'pista',
              label: 'Pista',
              file: 'Pista.png',
            ),
            vehicleItem(
              categoria: 'motocicleta',
              subtipo: 'trabajo',
              label: 'Trabajo',
              file: 'Trabajo.png',
            ),
            vehicleItem(
              categoria: 'motocicleta',
              subtipo: 'volteada',
              label: 'Volteada',
              file: 'Volteada.png',
            ),
          ],
        ),
        CroquisCatalogCategory(
          key: 'maquinaria',
          label: 'Maquinaria',
          items: <CroquisCatalogItem>[
            vehicleItem(
              categoria: 'maquinaria',
              subtipo: 'tractor',
              label: 'Tractor',
              file: 'Tractor.png',
              anchoOriginal: 120,
              altoOriginal: 80,
            ),
          ],
        ),
        CroquisCatalogCategory(
          key: 'peatones',
          label: 'Peatones',
          items: <CroquisCatalogItem>[
            vehicleItem(
              categoria: 'peatones',
              subtipo: 'peaton_1',
              label: 'Peatón 1',
              file: 'peaton_1.png',
              anchoOriginal: 60,
              altoOriginal: 100,
            ),
            vehicleItem(
              categoria: 'peatones',
              subtipo: 'peaton_2',
              label: 'Peatón 2',
              file: 'peaton_2.png',
              anchoOriginal: 60,
              altoOriginal: 100,
            ),
            vehicleItem(
              categoria: 'peatones',
              subtipo: 'peaton_3',
              label: 'Peatón 3',
              file: 'peaton_3.png',
              anchoOriginal: 60,
              altoOriginal: 100,
            ),
          ],
        ),
        CroquisCatalogCategory(
          key: 'animales',
          label: 'Animales',
          items: <CroquisCatalogItem>[
            vehicleItem(
              categoria: 'animales',
              subtipo: 'animal',
              label: 'Animal',
              file: 'animal.png',
            ),
            vehicleItem(
              categoria: 'animales',
              subtipo: 'cow',
              label: 'Vaca',
              file: 'cow.png',
            ),
            vehicleItem(
              categoria: 'animales',
              subtipo: 'horse',
              label: 'Caballo',
              file: 'horse.png',
            ),
          ],
        ),
      ];
}

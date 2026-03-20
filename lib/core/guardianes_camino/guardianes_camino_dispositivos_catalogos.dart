class GuardianesCaminoCatalogoLocal {
  final int id;
  final String nombre;
  final String titulo;
  final List<String> campos;

  const GuardianesCaminoCatalogoLocal({
    required this.id,
    required this.nombre,
    required this.titulo,
    required this.campos,
  });
}

class GuardianesCaminoDispositivosCatalogos {
  static const List<GuardianesCaminoCatalogoLocal> items =
      <GuardianesCaminoCatalogoLocal>[
        GuardianesCaminoCatalogoLocal(
          id: 1,
          nombre: 'PSV (PUESTO DE SEGURIDAD Y VIGILANCIA)',
          titulo: 'PSV (Puesto de Seguridad y Vigilancia)',
          campos: <String>[
            'cantidad',
            'vehiculos_inspeccionados',
            'personas_inspeccionadas',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 2,
          nombre: 'RSV (RECORRIDOS DE SEGURIDAD Y VIGILANCIA - PATRULLAJE)',
          titulo: 'RSV (Recorridos de Seguridad y Vigilancia - Patrullaje)',
          campos: <String>[
            'cantidad',
            'vehiculos_inspeccionados',
            'personas_inspeccionadas',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 3,
          nombre: 'DISPOSITIVO CASCO',
          titulo: 'Dispositivo Casco',
          campos: <String>[
            'cantidad',
            'vehiculos_impactados',
            'personas_impactadas',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 4,
          nombre: 'DISPOSITIVO CINTURON',
          titulo: 'Dispositivo Cinturón',
          campos: <String>[
            'cantidad',
            'vehiculos_impactados',
            'personas_impactadas',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 5,
          nombre: 'DISPOSITIVO CARRUSEL',
          titulo: 'Dispositivo Carrusel',
          campos: <String>[
            'cantidad',
            'vehiculos_impactados',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 6,
          nombre: 'CORDILLERA',
          titulo: 'Cordillera',
          campos: <String>[
            'cantidad',
            'vehiculos_impactados',
            'personas_impactadas',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 7,
          nombre: 'DISPOSITIVO ASIENTO SEGURO PASAJEROS MENORES',
          titulo: 'Dispositivo Asiento Seguro Pasajeros Menores',
          campos: <String>[
            'cantidad',
            'vehiculos_impactados',
            'personas_impactadas',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 8,
          nombre: 'CABALLEROS DEL CAMINO',
          titulo: 'Caballeros del Camino',
          campos: <String>[
            'cantidad',
            'acompanamientos',
            'abanderamientos',
            'auxilios_viales',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 9,
          nombre: 'PROXIMIDAD SOCIAL',
          titulo: 'Proximidad Social',
          campos: <String>[
            'prox_empresas',
            'prox_tiendas_conveniencia',
            'prox_escuelas',
            'prox_hospitales',
          ],
        ),
      ];
}

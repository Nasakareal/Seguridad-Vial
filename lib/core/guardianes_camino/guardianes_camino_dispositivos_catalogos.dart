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
            'vehiculos_inspeccionados',
            'personas_inspeccionadas',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 3,
          nombre: 'CASCO',
          titulo: 'Dispositivo Casco',
          campos: <String>[
            'vehiculos_impactados',
            'personas_impactadas',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 4,
          nombre: 'CINTURÓN',
          titulo: 'Dispositivo Cinturón',
          campos: <String>[
            'vehiculos_impactados',
            'personas_impactadas',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 5,
          nombre: 'CARRUSEL',
          titulo: 'Dispositivo Carrusel',
          campos: <String>[
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
            'vehiculos_impactados',
            'personas_impactadas',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 7,
          nombre: 'ASIENTO SEGURO PASAJEROS MENORES',
          titulo: 'Dispositivo Asiento Seguro Pasajeros Menores',
          campos: <String>[
            'vehiculos_impactados',
            'personas_impactadas',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 13,
          nombre: 'CABALLERO DEL CAMINO (PROXIMIDAD SOCIAL)',
          titulo: 'Caballero del Camino (Proximidad Social)',
          campos: <String>[
            'prox_empresas',
            'prox_tiendas_conveniencia',
            'prox_escuelas',
            'prox_hospitales',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 10,
          nombre: 'ACOMPAÑAMIENTOS',
          titulo: 'ACOMPAÑAMIENTOS (Escoltas, Caravanas, Emergencias, Otros)',
          campos: <String>[
            'tipo_acompanamiento',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 11,
          nombre: 'ABANDERAMIENTOS',
          titulo: 'ABANDERAMIENTOS (Siniestros, Eventos, Otros)',
          campos: <String>[
            'tipo_abanderamiento',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 12,
          nombre: 'AUXILIOS VIALES',
          titulo: 'AUXILIOS VIALES (Falla mecánica, Peatón, Otros)',
          campos: <String>[
            'tipo_auxilio_vial',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
        GuardianesCaminoCatalogoLocal(
          id: 14,
          nombre: 'ATENCIÓN A REPORTES C5',
          titulo: 'Atención a Reportes C5',
          campos: <String>[
            'folio_atendido',
            'motivo_folio',
            'estado_fuerza_participante',
            'crps_participantes',
            'kilometros_recorridos',
          ],
        ),
      ];
}

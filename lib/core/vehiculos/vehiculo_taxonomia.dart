class VehiculoTaxonomia {
  static const List<Map<String, String>> tiposGenerales = [
    {'value': 'automovil', 'label': 'Automóvil'},
    {'value': 'camioneta', 'label': 'Camioneta'},
    {'value': 'camion', 'label': 'Camión'},
    {'value': 'motocicleta', 'label': 'Motocicleta'},
    {'value': 'bicicleta', 'label': 'Bicicleta'},
    {'value': 'remolque', 'label': 'Remolque'},
    {'value': 'maquinaria', 'label': 'Maquinaria'},
    {'value': 'tren', 'label': 'Tren'},
    {'value': 'semoviente', 'label': 'Semoviente'},
  ];

  static const Map<String, List<String>> carrocerias = {
    'automovil': ['Sedán', 'Hatchback', 'Coupé', 'SUV', 'Convertible'],

    'camioneta': ['Pick-up', 'Panel', 'Vagoneta', 'Furgoneta', 'Van'],

    'camion': [
      'Caja seca',
      'Caja cerrada',
      'Caja abierta',
      'Plataforma',
      'Volteo',
      'Refrigerado',
      'Cisterna',
      'Pipa',
      'Grúa',
      'Torton',
      'Rabón',
      'Tracto',
      'Redilas',
    ],

    'motocicleta': [
      'Trabajo',
      'Cruiser',
      'Doble Propósito',
      'Scooter',
      'Enduro',
      'Naked',
      'Pista',
      'Chopper',
      'Cuatrimoto',
    ],

    'bicicleta': ['Montaña', 'Ruta', 'BMX', 'Urbana', 'Plegable'],

    'remolque': [
      'Plataforma',
      'Caja cerrada',
      'Caja seca',
      'Cama baja',
      'Refrigerado',
      'Volteo',
      'Góndola',
      'Dolly',
      'Portacontenedor',
    ],

    'maquinaria': [
      'Retroexcavadora',
      'Excavadora',
      'Cargador frontal',
      'Motoconformadora',
      'Bulldozer',
      'Rodillo compactador',
      'Grúa industrial',
      'Montacargas',
      'Tractor agrícola',
      'Pavimentadora',
      'Compactadora',
    ],

    'tren': [
      'Locomotora',
      'Vagón',
      'Tren de carga',
      'Tren de pasajeros',
      'Tranvía',
      'Metro',
    ],

    'semoviente': ['Caballo', 'Burro', 'Vaca', 'Mula', 'Otro animal de tiro'],
  };

  static List<String> carroceriasDeTipoGeneral(String? tipoGeneral) {
    if (tipoGeneral == null || tipoGeneral.trim().isEmpty) return const [];
    return carrocerias[tipoGeneral] ?? const [];
  }

  static String normalizeCarroceria(String raw) {
    final s = raw.trim().toLowerCase();

    final compact = s.replaceAll(RegExp(r'\s+'), '');

    if (compact.contains('hatch')) return 'Hatchback';
    if (s.contains('sedan') || s.contains('sedán')) return 'Sedán';
    if (s.contains('coupe') || s.contains('coupé')) return 'Coupé';
    if (s.contains('suv')) return 'SUV';
    if (s.contains('convert')) return 'Convertible';

    if (s.contains('wagon') || s.contains('station')) return 'Wagon';
    if (s.contains('minivan')) return 'Minivan';
    if (s.contains('crossover')) return 'Crossover';

    if (s.contains('pickup') || (s.contains('pick') && s.contains('up'))) {
      return 'Pick-up';
    }
    if (s.contains('doble') && s.contains('cab')) return 'Doble cabina';
    if ((s.contains('cabina') && s.contains('senc')) ||
        s.contains('regularcab')) {
      return 'Cabina sencilla';
    }
    if (s.contains('van')) return 'Van';
    if (s.contains('panel')) return 'Panel';
    if (s.contains('furg')) return 'Furgoneta';
    if (s.contains('vagoneta')) return 'Vagoneta';

    if (s.contains('tracto')) return 'Tractocamión';
    if (s.contains('torton')) return 'Torton';
    if (s.contains('rabon') || s.contains('rabón')) return 'Rabón';

    if (s.contains('caja') && s.contains('seca')) return 'Caja seca';
    if (s.contains('caja') && (s.contains('cerrada') || s.contains('cerr')))
      return 'Caja cerrada';
    if (s.contains('caja') && (s.contains('abierta') || s.contains('abier')))
      return 'Caja abierta';

    if (s.contains('plataforma')) return 'Plataforma';
    if (s.contains('volteo') || s.contains('volquete')) return 'Volteo';
    if (s.contains('refriger')) return 'Refrigerado';

    if (s.contains('cisterna')) return 'Cisterna';
    if (s.contains('pipa')) return 'Pipa';
    if (s.contains('grua') || s.contains('grúa')) return 'Grúa';

    if ((s.contains('cama') && s.contains('baja')) || s.contains('lowboy'))
      return 'Cama baja';
    if (s.contains('gondola') || s.contains('góndola')) return 'Góndola';
    if (s.contains('dolly')) return 'Dolly';
    if (s.contains('portacont')) return 'Portacontenedor';

    if (s.contains('cruiser') || s.contains('cruisier')) return 'Cruiser';
    if (s.contains('doble') &&
        (s.contains('proposito') || s.contains('propósito'))) {
      return 'Doble Propósito';
    }
    if (s.contains('scooter')) return 'Scooter';
    if (s.contains('enduro')) return 'Enduro';
    if (s.contains('naked')) return 'Naked';
    if (s.contains('pista') || s.contains('deport')) return 'Pista';
    if (s.contains('chopper')) return 'Chopper';
    if (s.contains('cuatri')) return 'Cuatrimoto';

    if (s.contains('retro') && s.contains('excav')) return 'Retroexcavadora';
    if (s.contains('excav')) return 'Excavadora';
    if (s.contains('cargador') &&
        (s.contains('frontal') || s.contains('front')))
      return 'Cargador frontal';
    if (s.contains('moto') && s.contains('conform')) return 'Motoconformadora';
    if (s.contains('bulldozer') || s.contains('topador')) return 'Bulldozer';
    if (s.contains('rodillo') && s.contains('compact'))
      return 'Rodillo compactador';
    if (s.contains('montac')) return 'Montacargas';
    if (s.contains('tractor')) return 'Tractor agrícola';
    if (s.contains('paviment')) return 'Pavimentadora';
    if (s.contains('compact')) return 'Compactadora';

    if (s.contains('locom')) return 'Locomotora';
    if (s.contains('vagon') || s.contains('vagón')) return 'Vagón';
    if (s.contains('tranvia') || s.contains('tranvía')) return 'Tranvía';
    if (s.contains('metro')) return 'Metro';
    if (s.contains('pasaj')) return 'Tren de pasajeros';
    if (s.contains('carga')) return 'Tren de carga';

    return _titleCase(raw);
  }

  static String _titleCase(String v) {
    final s = v.trim();
    if (s.isEmpty) return s;
    final parts = s.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts
        .map(
          (p) => p.length == 1
              ? p.toUpperCase()
              : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class VialidadesUrbanasCatalogo {
  final int id;
  final String nombre;
  final int orden;

  const VialidadesUrbanasCatalogo({
    required this.id,
    required this.nombre,
    required this.orden,
  });

  factory VialidadesUrbanasCatalogo.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) => int.tryParse('${value ?? ''}') ?? 0;

    return VialidadesUrbanasCatalogo(
      id: asInt(json['id']),
      nombre: (json['nombre'] ?? '').toString().trim(),
      orden: asInt(json['orden']),
    );
  }
}

class VialidadesUrbanasDispositivoDetalle {
  final int id;
  final int orden;
  final String tipo;
  final String titulo;
  final String contenido;
  final String ubicacion;
  final String hora;

  const VialidadesUrbanasDispositivoDetalle({
    required this.id,
    required this.orden,
    required this.tipo,
    required this.titulo,
    required this.contenido,
    required this.ubicacion,
    required this.hora,
  });

  factory VialidadesUrbanasDispositivoDetalle.fromJson(
    Map<String, dynamic> json,
  ) {
    int asInt(dynamic value) => int.tryParse('${value ?? ''}') ?? 0;
    String asText(dynamic value) => (value ?? '').toString().trim();

    return VialidadesUrbanasDispositivoDetalle(
      id: asInt(json['id']),
      orden: asInt(json['orden']),
      tipo: asText(json['tipo']).isEmpty ? 'texto' : asText(json['tipo']),
      titulo: asText(json['titulo']),
      contenido: asText(json['contenido']),
      ubicacion: asText(json['ubicacion']),
      hora: asText(json['hora']),
    );
  }
}

class VialidadesUrbanasDispositivoFoto {
  final int id;
  final String ruta;
  final String nombreOriginal;
  final int orden;
  final bool portada;
  final bool includedInShare;

  const VialidadesUrbanasDispositivoFoto({
    required this.id,
    required this.ruta,
    required this.nombreOriginal,
    required this.orden,
    required this.portada,
    required this.includedInShare,
  });

  factory VialidadesUrbanasDispositivoFoto.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) => int.tryParse('${value ?? ''}') ?? 0;
    String asText(dynamic value) => (value ?? '').toString().trim();

    return VialidadesUrbanasDispositivoFoto(
      id: asInt(json['id']),
      ruta: asText(json['ruta']),
      nombreOriginal: asText(json['nombre_original']),
      orden: asInt(json['orden']),
      portada: json['portada'] == true || '${json['portada']}' == '1',
      includedInShare:
          json['included_in_share'] == true ||
          '${json['included_in_share']}' == '1',
    );
  }
}

class VialidadesUrbanasDispositivo {
  final int id;
  final int catalogoId;
  final String catalogoNombre;
  final String fecha;
  final String hora;
  final String asunto;
  final String municipio;
  final String lugar;
  final String evento;
  final String objetivo;
  final String descripcion;
  final String narrativa;
  final String accionesRealizadas;
  final String observaciones;
  final String supervision;
  final int elementos;
  final int crp;
  final int motopatrullas;
  final int fenix;
  final int unidadesMotorizadas;
  final int patrullas;
  final int gruas;
  final int otrosApoyos;
  final int fotosCount;
  final int detallesCount;
  final String portadaRuta;
  final String creadorNombre;
  final String revisorNombre;
  final List<VialidadesUrbanasDispositivoDetalle> detalles;
  final List<VialidadesUrbanasDispositivoFoto> fotos;

  const VialidadesUrbanasDispositivo({
    required this.id,
    required this.catalogoId,
    required this.catalogoNombre,
    required this.fecha,
    required this.hora,
    required this.asunto,
    required this.municipio,
    required this.lugar,
    required this.evento,
    required this.objetivo,
    required this.descripcion,
    required this.narrativa,
    required this.accionesRealizadas,
    required this.observaciones,
    required this.supervision,
    required this.elementos,
    required this.crp,
    required this.motopatrullas,
    required this.fenix,
    required this.unidadesMotorizadas,
    required this.patrullas,
    required this.gruas,
    required this.otrosApoyos,
    required this.fotosCount,
    required this.detallesCount,
    required this.portadaRuta,
    required this.creadorNombre,
    required this.revisorNombre,
    required this.detalles,
    required this.fotos,
  });

  factory VialidadesUrbanasDispositivo.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) => int.tryParse('${value ?? ''}') ?? 0;
    String asText(dynamic value) => (value ?? '').toString().trim();
    Map<String, dynamic>? asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    final catalogo = asMap(json['catalogo']);
    final fotoPortada = asMap(json['fotoPortada']);
    final creador = asMap(json['creador']);
    final revisor = asMap(json['revisor']);
    final fotosRaw = json['fotos'] is List ? json['fotos'] as List : const [];
    final detallesRaw = json['detalles'] is List
        ? json['detalles'] as List
        : const [];
    final fotos = fotosRaw
        .whereType<Map>()
        .map(
          (item) => VialidadesUrbanasDispositivoFoto.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
    final detalles = detallesRaw
        .whereType<Map>()
        .map(
          (item) => VialidadesUrbanasDispositivoDetalle.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
    var portada = fotoPortada != null ? asText(fotoPortada['ruta']) : '';
    if (portada.isEmpty) {
      for (final foto in fotos) {
        if (foto.portada && foto.ruta.trim().isNotEmpty) {
          portada = foto.ruta.trim();
          break;
        }
      }
    }
    if (portada.isEmpty && fotos.isNotEmpty) {
      portada = fotos.first.ruta;
    }

    return VialidadesUrbanasDispositivo(
      id: asInt(json['id']),
      catalogoId: asInt(
        json['vialidad_dispositivo_catalogo_id'] ?? catalogo?['id'],
      ),
      catalogoNombre: asText(catalogo?['nombre']).isNotEmpty
          ? asText(catalogo?['nombre'])
          : 'Sin catalogo',
      fecha: asText(json['fecha']),
      hora: asText(json['hora']),
      asunto: asText(json['asunto']),
      municipio: asText(json['municipio']),
      lugar: asText(json['lugar']),
      evento: asText(json['evento']),
      objetivo: asText(json['objetivo']),
      descripcion: asText(json['descripcion']),
      narrativa: asText(json['narrativa']),
      accionesRealizadas: asText(json['acciones_realizadas']),
      observaciones: asText(json['observaciones']),
      supervision: asText(json['supervision']),
      elementos: asInt(json['elementos']),
      crp: asInt(json['crp']),
      motopatrullas: asInt(json['motopatrullas']),
      fenix: asInt(json['fenix']),
      unidadesMotorizadas: asInt(json['unidades_motorizadas']),
      patrullas: asInt(json['patrullas']),
      gruas: asInt(json['gruas']),
      otrosApoyos: asInt(json['otros_apoyos']),
      fotosCount: fotos.length,
      detallesCount: detalles.length,
      portadaRuta: portada,
      creadorNombre: asText(creador?['name']),
      revisorNombre: asText(revisor?['name']),
      detalles: detalles,
      fotos: fotos,
    );
  }

  int get totalUnidades => motopatrullas + unidadesMotorizadas + patrullas;

  String get resumen {
    final candidates = <String>[
      descripcion,
      objetivo,
      narrativa,
      observaciones,
      evento,
    ];

    for (final value in candidates) {
      if (value.trim().isNotEmpty) return value.trim();
    }

    return 'Sin resumen capturado.';
  }

  String get ubicacionResumen {
    final parts = <String>[
      if (lugar.trim().isNotEmpty) lugar.trim(),
      if (municipio.trim().isNotEmpty) municipio.trim(),
    ];

    return parts.isEmpty ? 'Sin lugar capturado' : parts.join(' • ');
  }

  List<String> get estadoFuerzaEtiquetas {
    final values = <String>[];
    if (elementos > 0) values.add('$elementos ELEM');
    if (crp > 0) values.add('$crp CRP');
    if (motopatrullas > 0) values.add('$motopatrullas MOTO');
    if (fenix > 0) values.add('$fenix FENIX');
    if (unidadesMotorizadas > 0) values.add('$unidadesMotorizadas U.M.');
    if (patrullas > 0) values.add('$patrullas PAT');
    if (gruas > 0) values.add('$gruas GRUAS');
    if (otrosApoyos > 0) values.add('$otrosApoyos OTROS');
    return values;
  }
}

class VialidadesUrbanasTotales {
  final int dispositivos;
  final int elementos;
  final int crp;
  final int motopatrullas;
  final int fenix;
  final int unidadesMotorizadas;
  final int patrullas;
  final int gruas;
  final int otrosApoyos;

  const VialidadesUrbanasTotales({
    this.dispositivos = 0,
    this.elementos = 0,
    this.crp = 0,
    this.motopatrullas = 0,
    this.fenix = 0,
    this.unidadesMotorizadas = 0,
    this.patrullas = 0,
    this.gruas = 0,
    this.otrosApoyos = 0,
  });

  factory VialidadesUrbanasTotales.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) => int.tryParse('${value ?? ''}') ?? 0;

    return VialidadesUrbanasTotales(
      dispositivos: asInt(json['dispositivos']),
      elementos: asInt(json['elementos']),
      crp: asInt(json['crp']),
      motopatrullas: asInt(json['motopatrullas']),
      fenix: asInt(json['fenix']),
      unidadesMotorizadas: asInt(json['unidades_motorizadas']),
      patrullas: asInt(json['patrullas']),
      gruas: asInt(json['gruas']),
      otrosApoyos: asInt(json['otros_apoyos']),
    );
  }

  int get totalUnidades => motopatrullas + unidadesMotorizadas + patrullas;
}

class VialidadesUrbanasIndexResult {
  final String fecha;
  final List<VialidadesUrbanasCatalogo> catalogos;
  final List<VialidadesUrbanasDispositivo> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const VialidadesUrbanasIndexResult({
    required this.fecha,
    required this.catalogos,
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

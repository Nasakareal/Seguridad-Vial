class ArchivoPagina<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  ArchivoPagina({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  factory ArchivoPagina.parse(
    dynamic json,
    T Function(Map<String, dynamic>) converter,
  ) {
    final map = archivoMap(json);
    final raw = map['data'];
    final values = raw is List ? raw : <dynamic>[];
    return ArchivoPagina<T>(
      items: values.map((item) => converter(archivoMap(item))).toList(),
      currentPage: archivoInt(map['current_page']) ?? 1,
      lastPage: archivoInt(map['last_page']) ?? 1,
      total: archivoInt(map['total']) ?? values.length,
    );
  }
}

Map<String, dynamic> archivoMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return <String, dynamic>{};
}

List<Map<String, dynamic>> archivoMaps(dynamic value) {
  if (value is! List) return [];
  return value.map((item) => archivoMap(item)).toList();
}

int? archivoInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? archivoDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool archivoBool(dynamic value) =>
    value == true || value == 1 || value?.toString() == '1';

String archivoText(dynamic value) => value?.toString() ?? '';

class ArchivoArea {
  final int id;
  final String codigo;
  final String nombre;
  final String tipo;
  final String descripcion;
  final double? ancho;
  final double? alto;
  final bool activo;
  final int anaquelesCount;

  const ArchivoArea({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.tipo,
    required this.descripcion,
    required this.ancho,
    required this.alto,
    required this.activo,
    required this.anaquelesCount,
  });

  factory ArchivoArea.fromJson(Map<String, dynamic> json) => ArchivoArea(
    id: archivoInt(json['id']) ?? 0,
    codigo: archivoText(json['codigo']),
    nombre: archivoText(json['nombre']),
    tipo: archivoText(json['tipo']),
    descripcion: archivoText(json['descripcion']),
    ancho: archivoDouble(json['plano_ancho']),
    alto: archivoDouble(json['plano_alto']),
    activo: archivoBool(json['activo']),
    anaquelesCount: archivoInt(json['anaqueles_count']) ?? 0,
  );
}

class ArchivoAnaquel {
  final int id;
  final int areaId;
  final String areaNombre;
  final String codigo;
  final String nombre;
  final int filas;
  final int columnas;
  final double? x;
  final double? y;
  final double? ancho;
  final double? alto;
  final int rotacion;
  final bool activo;
  final int bloquesCount;
  final List<ArchivoBloque> bloques;

  const ArchivoAnaquel({
    required this.id,
    required this.areaId,
    required this.areaNombre,
    required this.codigo,
    required this.nombre,
    required this.filas,
    required this.columnas,
    required this.x,
    required this.y,
    required this.ancho,
    required this.alto,
    required this.rotacion,
    required this.activo,
    required this.bloquesCount,
    required this.bloques,
  });

  factory ArchivoAnaquel.fromJson(Map<String, dynamic> json) {
    final area = archivoMap(json['area']);
    return ArchivoAnaquel(
      id: archivoInt(json['id']) ?? 0,
      areaId: archivoInt(json['area_id']) ?? archivoInt(area['id']) ?? 0,
      areaNombre: archivoText(area['nombre']),
      codigo: archivoText(json['codigo']),
      nombre: archivoText(json['nombre']),
      filas: archivoInt(json['total_filas']) ?? 1,
      columnas: archivoInt(json['total_columnas']) ?? 1,
      x: archivoDouble(json['plano_x']),
      y: archivoDouble(json['plano_y']),
      ancho: archivoDouble(json['plano_ancho']),
      alto: archivoDouble(json['plano_alto']),
      rotacion: archivoInt(json['rotacion']) ?? 0,
      activo: json['activo'] == null || archivoBool(json['activo']),
      bloquesCount: archivoInt(json['bloques_count']) ?? archivoMaps(json['bloques']).length,
      bloques: archivoMaps(json['bloques']).map(ArchivoBloque.fromJson).toList(),
    );
  }
}

class ArchivoBloque {
  final int id;
  final int anaquelId;
  final String anaquelCodigo;
  final String areaNombre;
  final String codigo;
  final int fila;
  final int columna;
  final int capacidad;
  final int ocupados;
  final int reservados;
  final int disponibles;
  final String orden;
  final String qrUuid;
  final bool activo;
  final String observaciones;
  final List<Map<String, dynamic>> libros;
  final List<Map<String, dynamic>> reservas;

  const ArchivoBloque({
    required this.id,
    required this.anaquelId,
    required this.anaquelCodigo,
    required this.areaNombre,
    required this.codigo,
    required this.fila,
    required this.columna,
    required this.capacidad,
    required this.ocupados,
    required this.reservados,
    required this.disponibles,
    required this.orden,
    required this.qrUuid,
    required this.activo,
    required this.observaciones,
    required this.libros,
    required this.reservas,
  });

  factory ArchivoBloque.fromJson(Map<String, dynamic> json) {
    final anaquel = archivoMap(json['anaquel']);
    final capacidad = archivoInt(json['capacidad_libros']) ?? 0;
    final ocupados = archivoInt(json['ocupados']) ?? 0;
    final reservados = archivoInt(json['reservados']) ?? 0;
    return ArchivoBloque(
      id: archivoInt(json['id']) ?? 0,
      anaquelId: archivoInt(json['anaquel_id']) ?? archivoInt(anaquel['id']) ?? 0,
      anaquelCodigo: archivoText(anaquel['codigo']),
      areaNombre: archivoText(anaquel['area_nombre']),
      codigo: archivoText(json['codigo']),
      fila: archivoInt(json['fila']) ?? 1,
      columna: archivoInt(json['columna']) ?? 1,
      capacidad: capacidad,
      ocupados: ocupados,
      reservados: reservados,
      disponibles: archivoInt(json['disponibles']) ?? (capacidad - ocupados - reservados).clamp(0, 1000000).toInt(),
      orden: archivoText(json['orden_apilado']),
      qrUuid: archivoText(json['qr_uuid']),
      activo: json['activo'] == null || archivoBool(json['activo']),
      observaciones: archivoText(json['observaciones']),
      libros: archivoMaps(json['libros']),
      reservas: archivoMaps(json['reservas']),
    );
  }
}

class ArchivoLibro {
  final int id;
  final String codigo;
  final String titulo;
  final String numero;
  final String qrUuid;
  final int? anioInicio;
  final int? anioFin;
  final String folioInicial;
  final String folioFinal;
  final String fechaInicio;
  final String fechaFin;
  final int? totalPaginas;
  final int paginasDigitalizadas;
  final String estadoDigitalizacion;
  final String estadoFisico;
  final int? bloqueDestinoId;
  final int? posicionDestino;
  final int? bloqueActualId;
  final int? posicionActual;
  final int? areaActualId;
  final String observaciones;
  final Map<String, dynamic> ubicacionActual;
  final Map<String, dynamic> ubicacionDestino;
  final Map<String, dynamic> areaActual;
  final List<ArchivoDocumento> documentos;
  final List<ArchivoFolio> folios;
  final List<ArchivoMovimiento> movimientos;

  const ArchivoLibro({
    required this.id,
    required this.codigo,
    required this.titulo,
    required this.numero,
    required this.qrUuid,
    required this.anioInicio,
    required this.anioFin,
    required this.folioInicial,
    required this.folioFinal,
    required this.fechaInicio,
    required this.fechaFin,
    required this.totalPaginas,
    required this.paginasDigitalizadas,
    required this.estadoDigitalizacion,
    required this.estadoFisico,
    required this.bloqueDestinoId,
    required this.posicionDestino,
    required this.bloqueActualId,
    required this.posicionActual,
    required this.areaActualId,
    required this.observaciones,
    required this.ubicacionActual,
    required this.ubicacionDestino,
    required this.areaActual,
    required this.documentos,
    required this.folios,
    required this.movimientos,
  });

  factory ArchivoLibro.fromJson(Map<String, dynamic> json) => ArchivoLibro(
    id: archivoInt(json['id']) ?? 0,
    codigo: archivoText(json['codigo']),
    titulo: archivoText(json['titulo']),
    numero: archivoText(json['numero_libro']),
    qrUuid: archivoText(json['qr_uuid']),
    anioInicio: archivoInt(json['anio_inicio']),
    anioFin: archivoInt(json['anio_fin']),
    folioInicial: archivoText(json['folio_inicial']),
    folioFinal: archivoText(json['folio_final']),
    fechaInicio: archivoText(json['fecha_inicio']),
    fechaFin: archivoText(json['fecha_fin']),
    totalPaginas: archivoInt(json['total_paginas']),
    paginasDigitalizadas: archivoInt(json['paginas_digitalizadas']) ?? 0,
    estadoDigitalizacion: archivoText(json['estado_digitalizacion']),
    estadoFisico: archivoText(json['estado_fisico']),
    bloqueDestinoId: archivoInt(json['bloque_destino_id']),
    posicionDestino: archivoInt(json['posicion_destino']),
    bloqueActualId: archivoInt(json['bloque_actual_id']),
    posicionActual: archivoInt(json['posicion_actual']),
    areaActualId: archivoInt(json['area_actual_id']),
    observaciones: archivoText(json['observaciones']),
    ubicacionActual: archivoMap(json['ubicacion_actual']),
    ubicacionDestino: archivoMap(json['ubicacion_destino']),
    areaActual: archivoMap(json['area_actual']),
    documentos: archivoMaps(json['documentos']).map(ArchivoDocumento.fromJson).toList(),
    folios: archivoMaps(json['folios']).map(ArchivoFolio.fromJson).toList(),
    movimientos: archivoMaps(json['movimientos_recientes']).map(ArchivoMovimiento.fromJson).toList(),
  );

  String get ubicacionTexto {
    final sitio = ubicacionActual.isNotEmpty ? ubicacionActual : ubicacionDestino;
    if (sitio.isEmpty) return areaActual['nombre']?.toString() ?? 'Sin ubicación';
    final pos = ubicacionActual.isNotEmpty ? posicionActual : posicionDestino;
    final a = archivoText(sitio['anaquel_codigo']);
    final b = archivoText(sitio['bloque_codigo']);
    return '$a · $b${pos == null ? '' : ' · Posición $pos'}';
  }
}

class ArchivoDocumento {
  final int id;
  final String nombre;
  final String nombreOriginal;
  final String mimeType;
  final int paginaInicio;
  final int paginaFin;
  final int tamanoBytes;
  final String estado;

  const ArchivoDocumento({
    required this.id,
    required this.nombre,
    required this.nombreOriginal,
    required this.mimeType,
    required this.paginaInicio,
    required this.paginaFin,
    required this.tamanoBytes,
    required this.estado,
  });

  factory ArchivoDocumento.fromJson(Map<String, dynamic> json) => ArchivoDocumento(
    id: archivoInt(json['id']) ?? 0,
    nombre: archivoText(json['nombre']),
    nombreOriginal: archivoText(json['nombre_original']),
    mimeType: archivoText(json['mime_type']),
    paginaInicio: archivoInt(json['pagina_inicio']) ?? 1,
    paginaFin: archivoInt(json['pagina_fin']) ?? 1,
    tamanoBytes: archivoInt(json['tamano_bytes']) ?? 0,
    estado: archivoText(json['estado_revision']),
  );
}

class ArchivoFolio {
  final int id;
  final String folio;
  final int anio;
  final int? pagina;
  final int? paginaDocumento;
  final int? documentoId;
  final String estado;
  final String fecha;

  const ArchivoFolio({
    required this.id,
    required this.folio,
    required this.anio,
    required this.pagina,
    required this.paginaDocumento,
    required this.documentoId,
    required this.estado,
    required this.fecha,
  });

  factory ArchivoFolio.fromJson(Map<String, dynamic> json) => ArchivoFolio(
    id: archivoInt(json['id']) ?? 0,
    folio: archivoText(json['folio']),
    anio: archivoInt(json['anio']) ?? 0,
    pagina: archivoInt(json['numero_pagina']),
    paginaDocumento: archivoInt(json['pagina_documento']),
    documentoId: archivoInt(json['documento_id']),
    estado: archivoText(json['estado_verificacion']),
    fecha: archivoText(json['fecha_siniestro']),
  );
}

class ArchivoMovimiento {
  final int id;
  final String tipo;
  final String fecha;
  final String motivo;
  final int? origenPosicion;
  final int? destinoPosicion;
  final Map<String, dynamic> usuario;

  const ArchivoMovimiento({
    required this.id,
    required this.tipo,
    required this.fecha,
    required this.motivo,
    required this.origenPosicion,
    required this.destinoPosicion,
    required this.usuario,
  });

  factory ArchivoMovimiento.fromJson(Map<String, dynamic> json) => ArchivoMovimiento(
    id: archivoInt(json['id']) ?? 0,
    tipo: archivoText(json['tipo']),
    fecha: archivoText(json['fecha_movimiento']),
    motivo: archivoText(json['motivo']),
    origenPosicion: archivoInt(json['origen_posicion']),
    destinoPosicion: archivoInt(json['destino_posicion']),
    usuario: archivoMap(json['usuario']),
  );
}

class ArchivoMapaArea {
  final ArchivoArea area;
  final List<ArchivoAnaquel> anaqueles;
  ArchivoMapaArea({required this.area, required this.anaqueles});

  factory ArchivoMapaArea.fromJson(Map<String, dynamic> json) => ArchivoMapaArea(
    area: ArchivoArea.fromJson(json),
    anaqueles: archivoMaps(json['anaqueles']).map(ArchivoAnaquel.fromJson).toList(),
  );
}

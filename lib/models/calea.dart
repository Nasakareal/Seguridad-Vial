class CaleaMeta {
  final int totalDirectivas;
  final List<String> categorias;

  const CaleaMeta({required this.totalDirectivas, required this.categorias});

  const CaleaMeta.empty() : totalDirectivas = 0, categorias = const [];

  factory CaleaMeta.fromJson(Map<String, dynamic> json) {
    final data = _map(json['data']) ?? json;
    return CaleaMeta(
      totalDirectivas: _integer(data['total_directivas']),
      categorias: _list(data['categorias'])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class CaleaDirectiva {
  final int id;
  final String codigo;
  final String titulo;
  final String categoria;
  final String descripcion;
  final CaleaVersion? version;
  final List<CaleaCoincidencia> coincidencias;

  const CaleaDirectiva({
    required this.id,
    required this.codigo,
    required this.titulo,
    required this.categoria,
    required this.descripcion,
    required this.version,
    this.coincidencias = const [],
  });

  factory CaleaDirectiva.fromJson(Map<String, dynamic> json) {
    final version = _map(json['version']);
    return CaleaDirectiva(
      id: _integer(json['id']),
      codigo: _text(json['codigo']),
      titulo: _text(json['titulo']),
      categoria: _text(json['categoria']),
      descripcion: _text(json['descripcion']),
      version: version == null ? null : CaleaVersion.fromJson(version),
      coincidencias: _list(json['coincidencias'])
          .map(_map)
          .whereType<Map<String, dynamic>>()
          .map(CaleaCoincidencia.fromJson)
          .toList(growable: false),
    );
  }
}

class CaleaVersion {
  final int id;
  final String numeroVersion;
  final String nombreVersion;
  final String fechaEmision;
  final String fechaRevision;
  final String areaResponsable;
  final String autoriza;
  final String realizadoPor;
  final String leyendaDocumento;
  final int numeroPaginas;
  final bool pdfDisponible;
  final String pdfUrl;
  final List<CaleaSeccion> secciones;

  const CaleaVersion({
    required this.id,
    required this.numeroVersion,
    required this.nombreVersion,
    required this.fechaEmision,
    required this.fechaRevision,
    required this.areaResponsable,
    required this.autoriza,
    required this.realizadoPor,
    required this.leyendaDocumento,
    required this.numeroPaginas,
    required this.pdfDisponible,
    required this.pdfUrl,
    required this.secciones,
  });

  factory CaleaVersion.fromJson(Map<String, dynamic> json) {
    final fechaEmision = _text(json['fecha_emision']);
    final mes = _text(json['mes_emision']);
    final anio = _text(json['anio_emision']);
    return CaleaVersion(
      id: _integer(json['id']),
      numeroVersion: _text(json['numero_version']),
      nombreVersion: _text(json['nombre_version']),
      fechaEmision: fechaEmision.isNotEmpty
          ? fechaEmision
          : [mes, anio].where((value) => value.isNotEmpty).join(' '),
      fechaRevision: _text(json['fecha_revision']),
      areaResponsable: _text(json['area_responsable']),
      autoriza: _text(json['autoriza']),
      realizadoPor: _text(json['realizado_por']),
      leyendaDocumento: _text(json['leyenda_documento']),
      numeroPaginas: _integer(json['numero_paginas']),
      pdfDisponible: _boolean(json['pdf_disponible']),
      pdfUrl: _text(json['pdf_url']),
      secciones: _list(json['secciones'])
          .map(_map)
          .whereType<Map<String, dynamic>>()
          .map(CaleaSeccion.fromJson)
          .toList(growable: false),
    );
  }
}

class CaleaSeccion {
  final int id;
  final int orden;
  final String numero;
  final String tipo;
  final String titulo;
  final String contenido;
  final int paginaInicio;
  final int paginaFin;
  final List<CaleaBloque> bloques;

  const CaleaSeccion({
    required this.id,
    required this.orden,
    required this.numero,
    required this.tipo,
    required this.titulo,
    required this.contenido,
    required this.paginaInicio,
    required this.paginaFin,
    required this.bloques,
  });

  factory CaleaSeccion.fromJson(Map<String, dynamic> json) => CaleaSeccion(
    id: _integer(json['id']),
    orden: _integer(json['orden']),
    numero: _text(json['numero']),
    tipo: _text(json['tipo']),
    titulo: _text(json['titulo']),
    contenido: cleanCaleaText(_text(json['contenido'])),
    paginaInicio: _integer(json['pagina_inicio']),
    paginaFin: _integer(json['pagina_fin']),
    bloques: _list(json['bloques'])
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .map(CaleaBloque.fromJson)
        .toList(growable: false),
  );
}

class CaleaBloque {
  final int id;
  final String numero;
  final String tipo;
  final String titulo;
  final String contenido;
  final int paginaInicio;
  final int paginaFin;
  final bool citable;
  final List<CaleaBloque> hijos;

  const CaleaBloque({
    required this.id,
    required this.numero,
    required this.tipo,
    required this.titulo,
    required this.contenido,
    required this.paginaInicio,
    required this.paginaFin,
    required this.citable,
    required this.hijos,
  });

  factory CaleaBloque.fromJson(Map<String, dynamic> json) => CaleaBloque(
    id: _integer(json['id']),
    numero: _text(json['numero']),
    tipo: _text(json['tipo']),
    titulo: _text(json['titulo']),
    contenido: cleanCaleaText(_text(json['contenido'])),
    paginaInicio: _integer(json['pagina_inicio']),
    paginaFin: _integer(json['pagina_fin']),
    citable: _boolean(json['citable']),
    hijos: _list(json['hijos'])
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .map(CaleaBloque.fromJson)
        .toList(growable: false),
  );
}

class CaleaCoincidencia {
  final String tipo;
  final String numero;
  final String titulo;
  final String contenido;
  final int paginaInicio;
  final int paginaFin;

  const CaleaCoincidencia({
    required this.tipo,
    required this.numero,
    required this.titulo,
    required this.contenido,
    required this.paginaInicio,
    required this.paginaFin,
  });

  factory CaleaCoincidencia.fromJson(Map<String, dynamic> json) =>
      CaleaCoincidencia(
        tipo: _text(json['tipo']),
        numero: _text(json['numero']),
        titulo: _text(json['titulo']),
        contenido: cleanCaleaText(_text(json['contenido'])),
        paginaInicio: _integer(json['pagina_inicio']),
        paginaFin: _integer(json['pagina_fin']),
      );
}

class CaleaEstudioGrupo {
  final String categoria;
  final List<CaleaDirectiva> directivas;

  const CaleaEstudioGrupo({required this.categoria, required this.directivas});

  factory CaleaEstudioGrupo.fromJson(Map<String, dynamic> json) =>
      CaleaEstudioGrupo(
        categoria: _text(json['categoria']),
        directivas: _list(json['directivas'])
            .map(_map)
            .whereType<Map<String, dynamic>>()
            .map(CaleaDirectiva.fromJson)
            .toList(growable: false),
      );
}

String cleanCaleaText(String value) {
  if (value.isEmpty) return value;
  return value
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</\s*(p|div|li|h[1-6])\s*>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
      .trim();
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<dynamic> _list(dynamic value) => value is List ? value : const [];
String _text(dynamic value) => value?.toString().trim() ?? '';
int _integer(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
bool _boolean(dynamic value) =>
    value == true || value == 1 || value?.toString().toLowerCase() == 'true';

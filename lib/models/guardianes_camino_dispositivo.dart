class GuardianesCaminoDispositivoCatalogo {
  final int id;
  final String nombre;
  final int orden;

  const GuardianesCaminoDispositivoCatalogo({
    required this.id,
    required this.nombre,
    required this.orden,
  });

  factory GuardianesCaminoDispositivoCatalogo.fromJson(
    Map<String, dynamic> json,
  ) {
    int asInt(dynamic value) => int.tryParse('${value ?? ''}') ?? 0;

    return GuardianesCaminoDispositivoCatalogo(
      id: asInt(json['id']),
      nombre: (json['nombre'] ?? '').toString().trim(),
      orden: asInt(json['orden']),
    );
  }
}

class GuardianesCaminoDispositivo {
  final int id;
  final int catalogoId;
  final String catalogoNombre;
  final String fecha;
  final String hora;
  final String lugar;
  final String carretera;
  final String tramo;
  final String kilometro;
  final String descripcion;
  final String narrativa;
  final String destacamentoNombre;
  final String nombreResponsable;
  final String cargoResponsable;
  final int estadoFuerzaParticipante;
  final int fotosCount;
  final bool requiereEvidencia;
  final double? lat;
  final double? lng;

  const GuardianesCaminoDispositivo({
    required this.id,
    required this.catalogoId,
    required this.catalogoNombre,
    required this.fecha,
    required this.hora,
    required this.lugar,
    required this.carretera,
    required this.tramo,
    required this.kilometro,
    required this.descripcion,
    required this.narrativa,
    required this.destacamentoNombre,
    required this.nombreResponsable,
    required this.cargoResponsable,
    required this.estadoFuerzaParticipante,
    required this.fotosCount,
    required this.requiereEvidencia,
    required this.lat,
    required this.lng,
  });

  factory GuardianesCaminoDispositivo.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) => int.tryParse('${value ?? ''}') ?? 0;
    double? asDouble(dynamic value) => double.tryParse('${value ?? ''}');
    String asText(dynamic value) => (value ?? '').toString().trim();

    final catalogo = json['catalogo'];
    final catalogoMap = catalogo is Map<String, dynamic>
        ? catalogo
        : (catalogo is Map ? Map<String, dynamic>.from(catalogo) : null);

    final fotos = json['fotos'];
    final fotosCount = fotos is List ? fotos.length : 0;

    return GuardianesCaminoDispositivo(
      id: asInt(json['id']),
      catalogoId: asInt(
        json['operativo_dispositivo_catalogo_id'] ?? catalogoMap?['id'],
      ),
      catalogoNombre: asText(catalogoMap?['nombre']).isNotEmpty
          ? asText(catalogoMap?['nombre'])
          : 'Dispositivo',
      fecha: asText(json['fecha']),
      hora: asText(json['hora']),
      lugar: asText(json['lugar']),
      carretera: asText(json['carretera']),
      tramo: asText(json['tramo']),
      kilometro: asText(json['kilometro']),
      descripcion: asText(json['descripcion']),
      narrativa: asText(json['narrativa']),
      destacamentoNombre: asText(json['destacamento_nombre_snapshot']),
      nombreResponsable: asText(json['nombre_responsable']),
      cargoResponsable: asText(json['cargo_responsable']),
      estadoFuerzaParticipante: asInt(json['estado_fuerza_participante']),
      fotosCount: fotosCount,
      requiereEvidencia:
          json['requiere_evidencia'] == true ||
          '${json['requiere_evidencia']}'.trim() == '1',
      lat: asDouble(json['lat']),
      lng: asDouble(json['lng']),
    );
  }

  String get ubicacionResumen {
    final parts = <String>[
      if (lugar.isNotEmpty) lugar,
      if (carretera.isNotEmpty) carretera,
      if (tramo.isNotEmpty) tramo,
      if (kilometro.isNotEmpty) 'km $kilometro',
    ];
    return parts.isEmpty ? 'Sin ubicación registrada' : parts.join(' • ');
  }

  String get resumen {
    if (descripcion.isNotEmpty) return descripcion;
    if (narrativa.isNotEmpty) return narrativa;
    return 'Sin descripción capturada.';
  }
}

class GuardianesCaminoDispositivosIndexResult {
  final List<GuardianesCaminoDispositivo> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const GuardianesCaminoDispositivosIndexResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

class GuardianesCaminoDispositivosCreateMeta {
  final List<GuardianesCaminoDispositivoCatalogo> catalogos;

  const GuardianesCaminoDispositivosCreateMeta({required this.catalogos});
}

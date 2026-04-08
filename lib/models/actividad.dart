import 'actividad_categoria.dart';
import 'actividad_subcategoria.dart';

class ActividadRef {
  final int id;
  final String nombre;

  const ActividadRef({required this.id, required this.nombre});

  factory ActividadRef.fromJson(Map<String, dynamic> json) {
    return ActividadRef(
      id: _asInt(json['id']),
      nombre: _asNullableString(json['nombre']) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre};
}

class ActividadFoto {
  final int id;
  final int? orden;
  final String? fotoPath;

  const ActividadFoto({required this.id, required this.orden, required this.fotoPath});

  factory ActividadFoto.fromJson(Map<String, dynamic> json) {
    return ActividadFoto(
      id: _asInt(json['id']),
      orden: _asNullableInt(json['orden']),
      fotoPath:
          _asNullableString(json['foto_path']) ??
          _asNullableString(json['foto_url']) ??
          _asNullableString(json['foto']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orden': orden,
    'foto_path': fotoPath,
  };
}

class Actividad {
  final int id;
  final int actividadCategoriaId;
  final int? actividadSubcategoriaId;
  final String nombre;
  final int cantidad;
  final String? fotoPath;
  final String? fotoNombreOriginal;
  final String? fotoHash;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? fecha;
  final String? hora;
  final String? lugar;
  final String? municipio;
  final String? carretera;
  final String? tramo;
  final String? kilometro;
  final double? lat;
  final double? lng;
  final String? coordenadasTexto;
  final String? fuenteUbicacion;
  final String? notaGeo;
  final String? motivo;
  final String? narrativa;
  final String? accionesRealizadas;
  final String? observaciones;
  final int personasAlcanzadas;
  final int personasParticipantes;
  final int personasDetenidas;
  final String? elementosParticipantesTexto;
  final String? patrullasParticipantesTexto;
  final int? destacamentoId;
  final ActividadCategoria? categoria;
  final ActividadSubcategoria? subcategoria;
  final ActividadRef? unidad;
  final ActividadRef? delegacion;
  final ActividadRef? destacamento;
  final List<ActividadFoto> fotos;

  const Actividad({
    required this.id,
    required this.actividadCategoriaId,
    required this.actividadSubcategoriaId,
    required this.nombre,
    required this.cantidad,
    required this.fotoPath,
    required this.fotoNombreOriginal,
    required this.fotoHash,
    required this.createdAt,
    required this.updatedAt,
    required this.fecha,
    required this.hora,
    required this.lugar,
    required this.municipio,
    required this.carretera,
    required this.tramo,
    required this.kilometro,
    required this.lat,
    required this.lng,
    required this.coordenadasTexto,
    required this.fuenteUbicacion,
    required this.notaGeo,
    required this.motivo,
    required this.narrativa,
    required this.accionesRealizadas,
    required this.observaciones,
    required this.personasAlcanzadas,
    required this.personasParticipantes,
    required this.personasDetenidas,
    required this.elementosParticipantesTexto,
    required this.patrullasParticipantesTexto,
    required this.destacamentoId,
    required this.categoria,
    required this.subcategoria,
    required this.unidad,
    required this.delegacion,
    required this.destacamento,
    required this.fotos,
  });

  factory Actividad.fromJson(Map<String, dynamic> json) {
    final cat = json['categoria'];
    final sub = json['subcategoria'];
    final unidad = json['unidad'];
    final delegacion = json['delegacion'];
    final destacamento = json['destacamento'];
    final fotosRaw = json['fotos'];

    return Actividad(
      id: _asInt(json['id']),
      actividadCategoriaId: _asInt(json['actividad_categoria_id']),
      actividadSubcategoriaId: _asNullableInt(
        json['actividad_subcategoria_id'],
      ),
      nombre: _asNullableString(json['nombre']) ?? '',
      cantidad: _asInt(json['cantidad']),
      fotoPath:
          _asNullableString(json['foto_path']) ??
          _asNullableString(json['foto_url']) ??
          _asNullableString(json['foto']),
      fotoNombreOriginal: _asNullableString(json['foto_nombre_original']),
      fotoHash: _asNullableString(json['foto_hash']),
      createdAt: _asNullableDate(json['created_at']),
      updatedAt: _asNullableDate(json['updated_at']),
      fecha: _asNullableString(json['fecha']),
      hora: _asNullableString(json['hora']),
      lugar: _asNullableString(json['lugar']),
      municipio: _asNullableString(json['municipio']),
      carretera: _asNullableString(json['carretera']),
      tramo: _asNullableString(json['tramo']),
      kilometro: _asNullableString(json['kilometro']),
      lat: _asNullableDouble(json['lat']),
      lng: _asNullableDouble(json['lng']),
      coordenadasTexto: _asNullableString(json['coordenadas_texto']),
      fuenteUbicacion: _asNullableString(json['fuente_ubicacion']),
      notaGeo: _asNullableString(json['nota_geo']),
      motivo: _asNullableString(json['motivo']),
      narrativa: _asNullableString(json['narrativa']),
      accionesRealizadas: _asNullableString(json['acciones_realizadas']),
      observaciones: _asNullableString(json['observaciones']),
      personasAlcanzadas: _asInt(json['personas_alcanzadas']),
      personasParticipantes: _asInt(json['personas_participantes']),
      personasDetenidas: _asInt(json['personas_detenidas']),
      elementosParticipantesTexto: _asNullableString(
        json['elementos_participantes_texto'],
      ),
      patrullasParticipantesTexto: _asNullableString(
        json['patrullas_participantes_texto'],
      ),
      destacamentoId: _asNullableInt(json['destacamento_id']),
      categoria: (cat is Map)
          ? ActividadCategoria.fromJson(Map<String, dynamic>.from(cat))
          : null,
      subcategoria: (sub is Map)
          ? ActividadSubcategoria.fromJson(Map<String, dynamic>.from(sub))
          : null,
      unidad: (unidad is Map)
          ? ActividadRef.fromJson(Map<String, dynamic>.from(unidad))
          : null,
      delegacion: (delegacion is Map)
          ? ActividadRef.fromJson(Map<String, dynamic>.from(delegacion))
          : null,
      destacamento: (destacamento is Map)
          ? ActividadRef.fromJson(Map<String, dynamic>.from(destacamento))
          : null,
      fotos: (fotosRaw is List)
          ? fotosRaw
                .whereType<Map>()
                .map((e) => ActividadFoto.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const <ActividadFoto>[],
    );
  }

  List<String> get allPhotoPaths {
    final items = <String>[];

    for (final foto in fotos) {
      final path = (foto.fotoPath ?? '').trim();
      if (path.isNotEmpty && !items.contains(path)) {
        items.add(path);
      }
    }

    final main = (fotoPath ?? '').trim();
    if (main.isNotEmpty && !items.contains(main)) {
      items.add(main);
    }

    return items;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'actividad_categoria_id': actividadCategoriaId,
    'actividad_subcategoria_id': actividadSubcategoriaId,
    'nombre': nombre,
    'cantidad': cantidad,
    'foto_path': fotoPath,
    'foto_nombre_original': fotoNombreOriginal,
    'foto_hash': fotoHash,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'fecha': fecha,
    'hora': hora,
    'lugar': lugar,
    'municipio': municipio,
    'carretera': carretera,
    'tramo': tramo,
    'kilometro': kilometro,
    'lat': lat,
    'lng': lng,
    'coordenadas_texto': coordenadasTexto,
    'fuente_ubicacion': fuenteUbicacion,
    'nota_geo': notaGeo,
    'motivo': motivo,
    'narrativa': narrativa,
    'acciones_realizadas': accionesRealizadas,
    'observaciones': observaciones,
    'personas_alcanzadas': personasAlcanzadas,
    'personas_participantes': personasParticipantes,
    'personas_detenidas': personasDetenidas,
    'elementos_participantes_texto': elementosParticipantesTexto,
    'patrullas_participantes_texto': patrullasParticipantesTexto,
    'destacamento_id': destacamentoId,
    'categoria': categoria?.toJson(),
    'subcategoria': subcategoria?.toJson(),
    'unidad': unidad?.toJson(),
    'delegacion': delegacion?.toJson(),
    'destacamento': destacamento?.toJson(),
    'fotos': fotos.map((e) => e.toJson()).toList(),
  };
}

int _asInt(dynamic v) {
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

int? _asNullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

double? _asNullableDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString());
}

String? _asNullableString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _asNullableDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

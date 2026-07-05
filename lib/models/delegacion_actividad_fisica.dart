class DelegacionActividadFisica {
  final int id;
  final int? delegacionId;
  final DelegacionActividadFisicaDelegacion? delegacion;
  final String fecha;
  final String? hora;
  final String tipoEjercicio;
  final int elementosParticipantes;
  final String? fotoPath;
  final String? fotoUrl;
  final String? fotoNombreOriginal;
  final DelegacionActividadFisicaUsuario? capturo;
  final String? createdAt;
  final String? updatedAt;

  const DelegacionActividadFisica({
    required this.id,
    required this.delegacionId,
    required this.delegacion,
    required this.fecha,
    required this.hora,
    required this.tipoEjercicio,
    required this.elementosParticipantes,
    required this.fotoPath,
    required this.fotoUrl,
    required this.fotoNombreOriginal,
    required this.capturo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DelegacionActividadFisica.fromJson(Map<String, dynamic> json) {
    final delegacion = json['delegacion'];
    final capturo = json['capturo'];

    return DelegacionActividadFisica(
      id: _readInt(json['id']),
      delegacionId: _readNullableInt(json['delegacion_id']),
      delegacion: delegacion is Map
          ? DelegacionActividadFisicaDelegacion.fromJson(
              Map<String, dynamic>.from(delegacion),
            )
          : null,
      fecha: _readText(json['fecha']) ?? '',
      hora: _normalizeTime(_readText(json['hora'])),
      tipoEjercicio: _readText(json['tipo_ejercicio']) ?? '',
      elementosParticipantes: _readInt(json['elementos_participantes']),
      fotoPath: _readText(json['foto_path']),
      fotoUrl: _readText(json['foto_url']),
      fotoNombreOriginal: _readText(json['foto_nombre_original']),
      capturo: capturo is Map
          ? DelegacionActividadFisicaUsuario.fromJson(
              Map<String, dynamic>.from(capturo),
            )
          : null,
      createdAt: _readText(json['created_at']),
      updatedAt: _readText(json['updated_at']),
    );
  }

  String get fechaCorta => _formatDate(fecha);

  String get horaCorta {
    final value = hora?.trim() ?? '';
    return value.isEmpty ? 'Sin hora' : value;
  }

  String get delegacionLabel {
    final value = delegacion?.displayName.trim() ?? '';
    return value.isEmpty ? 'Sin delegacion' : value;
  }

  String get capturoLabel {
    final value = capturo?.name.trim() ?? '';
    return value.isEmpty ? 'Sin capturista' : value;
  }
}

class DelegacionActividadFisicaPage {
  final List<DelegacionActividadFisica> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const DelegacionActividadFisicaPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

class DelegacionActividadFisicaDelegacion {
  final int id;
  final String clave;
  final String nombre;
  final String municipio;
  final DelegacionActividadFisicaDelegacion? padre;

  const DelegacionActividadFisicaDelegacion({
    required this.id,
    required this.clave,
    required this.nombre,
    required this.municipio,
    this.padre,
  });

  factory DelegacionActividadFisicaDelegacion.fromJson(
    Map<String, dynamic> json,
  ) {
    final padre = json['padre'];
    return DelegacionActividadFisicaDelegacion(
      id: _readInt(json['id']),
      clave: _readText(json['clave']) ?? '',
      nombre: _readText(json['nombre'] ?? json['name']) ?? '',
      municipio: _readText(json['municipio']) ?? '',
      padre: padre is Map
          ? DelegacionActividadFisicaDelegacion.fromJson(
              Map<String, dynamic>.from(padre),
            )
          : null,
    );
  }

  String get displayName {
    final pieces = <String>[
      if (clave.trim().isNotEmpty) clave.trim(),
      if (nombre.trim().isNotEmpty) nombre.trim(),
      if (municipio.trim().isNotEmpty) municipio.trim(),
    ];
    if (pieces.isEmpty) return 'Delegacion $id';
    return pieces.join(' - ');
  }
}

class DelegacionActividadFisicaUsuario {
  final int id;
  final String name;

  const DelegacionActividadFisicaUsuario({
    required this.id,
    required this.name,
  });

  factory DelegacionActividadFisicaUsuario.fromJson(Map<String, dynamic> json) {
    return DelegacionActividadFisicaUsuario(
      id: _readInt(json['id']),
      name: _readText(json['name'] ?? json['nombre']) ?? '',
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

int? _readNullableInt(dynamic value) {
  final parsed = _readInt(value);
  return parsed > 0 ? parsed : null;
}

String? _readText(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

String? _normalizeTime(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  final hhmm = RegExp(r'(\d{2}):(\d{2})').firstMatch(value);
  if (hhmm != null) {
    return '${hhmm.group(1)}:${hhmm.group(2)}';
  }
  return value;
}

String _formatDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'Sin fecha';

  try {
    final parsed = DateTime.parse(value);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year}';
  } catch (_) {
    return value;
  }
}

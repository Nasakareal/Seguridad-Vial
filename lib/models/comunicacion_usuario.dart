class ComunicacionUsuario {
  final int id;
  final String nombre;

  final String? email;

  final int? unidadId;
  final String? unidad;

  final int? turnoId;
  final String? turno;

  final List<String> roles;

  final bool puedeEnviar;

  const ComunicacionUsuario({
    required this.id,
    required this.nombre,
    this.email,
    this.unidadId,
    this.unidad,
    this.turnoId,
    this.turno,
    this.roles = const [],
    this.puedeEnviar = true,
  });

  factory ComunicacionUsuario.fromJson(Map<String, dynamic> json) {
    return ComunicacionUsuario(
      id: _toInt(json['id']) ?? 0,
      nombre: json['nombre']?.toString() ?? 'Usuario',
      email: _nullableString(json['email']),
      unidadId: _toInt(json['unidad_id']),
      unidad: _extraerNombre(json['unidad']),
      turnoId: _toInt(json['turno_id']),
      turno: _extraerNombre(json['turno']),
      roles: _toStringList(json['roles']),
      puedeEnviar: json.containsKey('puede_enviar')
          ? _toBool(json['puede_enviar'])
          : true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'unidad_id': unidadId,
      'unidad': unidad,
      'turno_id': turnoId,
      'turno': turno,
      'roles': roles,
      'puede_enviar': puedeEnviar,
    };
  }

  ComunicacionUsuario copyWith({
    int? id,
    String? nombre,
    String? email,
    int? unidadId,
    String? unidad,
    int? turnoId,
    String? turno,
    List<String>? roles,
    bool? puedeEnviar,
  }) {
    return ComunicacionUsuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      unidadId: unidadId ?? this.unidadId,
      unidad: unidad ?? this.unidad,
      turnoId: turnoId ?? this.turnoId,
      turno: turno ?? this.turno,
      roles: roles ?? this.roles,
      puedeEnviar: puedeEnviar ?? this.puedeEnviar,
    );
  }

  String get nombreVisible {
    final texto = nombre.trim();

    return texto.isEmpty ? 'Usuario' : texto;
  }

  String get iniciales {
    final partes = nombreVisible
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();

    if (partes.isEmpty) {
      return 'U';
    }

    if (partes.length == 1) {
      return partes.first.substring(0, 1).toUpperCase();
    }

    return (partes.first.substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }

  String get detalle {
    final partes = <String>[];

    if (unidad != null && unidad!.trim().isNotEmpty) {
      partes.add(unidad!.trim());
    }

    if (turno != null && turno!.trim().isNotEmpty) {
      partes.add(turno!.trim());
    }

    if (roles.isNotEmpty) {
      partes.add(roles.join(', '));
    }

    return partes.join(' · ');
  }

  bool get tieneUnidad =>
      unidadId != null || (unidad != null && unidad!.trim().isNotEmpty);

  bool get tieneTurno =>
      turnoId != null || (turno != null && turno!.trim().isNotEmpty);

  bool tieneRol(String rol) {
    final buscado = rol.trim().toLowerCase();

    return roles.any((item) => item.trim().toLowerCase() == buscado);
  }

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static bool _toBool(dynamic value) {
    if (value == null) {
      return false;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final texto = value.toString().trim().toLowerCase();

    return texto == '1' ||
        texto == 'true' ||
        texto == 'yes' ||
        texto == 'si' ||
        texto == 'sí';
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final texto = value.toString().trim();

    return texto.isEmpty ? null : texto;
  }

  static String? _extraerNombre(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Map) {
      final mapa = Map<String, dynamic>.from(value);

      return _nullableString(mapa['nombre']);
    }

    return _nullableString(value);
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) {
      return const [];
    }

    if (value is List) {
      return value
          .map((item) {
            if (item is Map) {
              final mapa = Map<String, dynamic>.from(item);

              return mapa['name']?.toString().trim() ??
                  mapa['nombre']?.toString().trim() ??
                  '';
            }

            return item.toString().trim();
          })
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return const [];
  }

  @override
  String toString() {
    return nombreVisible;
  }
}

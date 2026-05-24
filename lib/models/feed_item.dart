enum FeedItemType { hecho, actividad, carreteras, vialidades }

class FeedItem {
  final FeedItemType type;
  final int id;
  final int userId;
  final String userName;
  final String resumen;
  final String? categoriaNombre;
  final String? subcategoriaNombre;
  final String? fotoUrl;
  final DateTime? createdAt;
  final String? showUrl;
  final int? unidadId;
  final String? unidadNombre;
  final int? delegacionId;
  final String? delegacionNombre;

  const FeedItem({
    required this.type,
    required this.id,
    required this.userId,
    required this.userName,
    required this.resumen,
    required this.categoriaNombre,
    required this.subcategoriaNombre,
    required this.fotoUrl,
    required this.createdAt,
    required this.showUrl,
    required this.unidadId,
    required this.unidadNombre,
    required this.delegacionId,
    required this.delegacionNombre,
  });

  String? get unidadLabel {
    final nombre = _asNullableString(unidadNombre);
    if (nombre != null) return nombre;

    final id = unidadId;
    return id == null ? null : _fallbackUnidadNombre(id);
  }

  String? get delegacionLabel {
    final nombre = _asNullableString(delegacionNombre);
    if (nombre != null) return nombre;

    final id = delegacionId;
    return id == null ? null : 'Delegación $id';
  }

  String? get origenLabel {
    final unidad = unidadLabel;
    final delegacion = delegacionLabel;
    final parts = <String>[
      if (delegacion != null) 'Delegación: $delegacion',
      if (unidad != null) 'Unidad: $unidad',
    ];

    return parts.isEmpty ? null : parts.join(' • ');
  }

  FeedItem copyWith({
    String? fotoUrl,
    int? unidadId,
    String? unidadNombre,
    int? delegacionId,
    String? delegacionNombre,
  }) {
    return FeedItem(
      type: type,
      id: id,
      userId: userId,
      userName: userName,
      resumen: resumen,
      categoriaNombre: categoriaNombre,
      subcategoriaNombre: subcategoriaNombre,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      createdAt: createdAt,
      showUrl: showUrl,
      unidadId: unidadId ?? this.unidadId,
      unidadNombre: unidadNombre ?? this.unidadNombre,
      delegacionId: delegacionId ?? this.delegacionId,
      delegacionNombre: delegacionNombre ?? this.delegacionNombre,
    );
  }

  static FeedItemType _parseType(dynamic v) {
    final s = (v ?? '').toString().trim().toUpperCase();
    if (s == 'HECHO') return FeedItemType.hecho;
    if (s == 'CARRETERAS') return FeedItemType.carreteras;
    if (s == 'VIALIDADES') return FeedItemType.vialidades;
    return FeedItemType.actividad;
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static int? _asNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v > 0 ? v : null;
    if (v is num) {
      final parsed = v.toInt();
      return parsed > 0 ? parsed : null;
    }

    final parsed = int.tryParse(v.toString());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static String? _asNullableString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _nameFromObject(dynamic raw) {
    if (raw is Map) {
      return _asNullableString(
        raw['nombre'] ?? raw['name'] ?? raw['label'] ?? raw['descripcion'],
      );
    }

    return _asNullableString(raw);
  }

  static int? _unidadIdFromUnidadObject(dynamic raw) {
    if (raw is Map) {
      return _asNullableInt(
        raw['id'] ??
            raw['value'] ??
            raw['unidad_id'] ??
            raw['unidadId'] ??
            raw['unidad_org_id'] ??
            raw['unidadOrgId'],
      );
    }

    return _asNullableInt(raw);
  }

  static int? _unidadIdFromRecord(dynamic raw) {
    if (raw is! Map) return null;

    return _asNullableInt(
          raw['unidad_id'] ??
              raw['unidadId'] ??
              raw['unidad_org_id'] ??
              raw['unidadOrgId'],
        ) ??
        _unidadIdFromUnidadObject(raw['unidad']) ??
        _unidadIdFromUnidadObject(raw['unidad_meta']) ??
        _unidadIdFromUnidadObject(raw['unidadMeta']);
  }

  static int? _unidadIdFromJson(Map<String, dynamic> json) {
    final direct = _unidadIdFromRecord(json);
    if (direct != null) return direct;

    for (final key in const <String>[
      'actividad',
      'hecho',
      'dispositivo',
      'registro',
      'source',
      'data',
    ]) {
      final nested = _unidadIdFromRecord(json[key]);
      if (nested != null) return nested;
    }

    for (final key in const <String>['user', 'usuario', 'created_by_user']) {
      final ownerUnidadId = _unidadIdFromRecord(json[key]);
      if (ownerUnidadId != null) return ownerUnidadId;
    }

    return null;
  }

  static String? _unidadNombreFromRecord(dynamic raw) {
    if (raw is! Map) return null;

    return _asNullableString(
          raw['unidad_nombre'] ??
              raw['unidadNombre'] ??
              raw['unidad_org_nombre'] ??
              raw['unidadOrgNombre'] ??
              raw['unit_name'],
        ) ??
        _nameFromObject(raw['unidad']) ??
        _nameFromObject(raw['unidad_meta']) ??
        _nameFromObject(raw['unidadMeta']);
  }

  static String? _unidadNombreFromJson(Map<String, dynamic> json) {
    final direct = _unidadNombreFromRecord(json);
    if (direct != null) return direct;

    for (final key in const <String>[
      'actividad',
      'hecho',
      'dispositivo',
      'registro',
      'source',
      'data',
    ]) {
      final nested = _unidadNombreFromRecord(json[key]);
      if (nested != null) return nested;
    }

    for (final key in const <String>['user', 'usuario', 'created_by_user']) {
      final ownerUnidad = _unidadNombreFromRecord(json[key]);
      if (ownerUnidad != null) return ownerUnidad;
    }

    return null;
  }

  static int? _delegacionIdFromDelegacionObject(dynamic raw) {
    if (raw is Map) {
      return _asNullableInt(
        raw['id'] ??
            raw['value'] ??
            raw['delegacion_id'] ??
            raw['delegacionId'] ??
            raw['delegacion_org_id'],
      );
    }

    return _asNullableInt(raw);
  }

  static int? _delegacionIdFromRecord(dynamic raw) {
    if (raw is! Map) return null;

    return _asNullableInt(
          raw['delegacion_id'] ??
              raw['delegacionId'] ??
              raw['delegacion_org_id'],
        ) ??
        _delegacionIdFromDelegacionObject(raw['delegacion']) ??
        _delegacionIdFromDelegacionObject(raw['delegacion_meta']) ??
        _delegacionIdFromDelegacionObject(raw['delegacionMeta']);
  }

  static int? _delegacionIdFromJson(Map<String, dynamic> json) {
    final direct = _delegacionIdFromRecord(json);
    if (direct != null) return direct;

    for (final key in const <String>[
      'actividad',
      'hecho',
      'dispositivo',
      'registro',
      'source',
      'data',
    ]) {
      final nested = _delegacionIdFromRecord(json[key]);
      if (nested != null) return nested;
    }

    for (final key in const <String>['user', 'usuario', 'created_by_user']) {
      final ownerDelegacionId = _delegacionIdFromRecord(json[key]);
      if (ownerDelegacionId != null) return ownerDelegacionId;
    }

    return null;
  }

  static String? _delegacionNombreFromRecord(dynamic raw) {
    if (raw is! Map) return null;

    return _asNullableString(
          raw['delegacion_nombre'] ??
              raw['delegacionNombre'] ??
              raw['delegacion_org_nombre'] ??
              raw['delegacionOrgNombre'],
        ) ??
        _nameFromObject(raw['delegacion']) ??
        _nameFromObject(raw['delegacion_meta']) ??
        _nameFromObject(raw['delegacionMeta']);
  }

  static String? _delegacionNombreFromJson(Map<String, dynamic> json) {
    final direct = _delegacionNombreFromRecord(json);
    if (direct != null) return direct;

    for (final key in const <String>[
      'actividad',
      'hecho',
      'dispositivo',
      'registro',
      'source',
      'data',
    ]) {
      final nested = _delegacionNombreFromRecord(json[key]);
      if (nested != null) return nested;
    }

    for (final key in const <String>['user', 'usuario', 'created_by_user']) {
      final ownerDelegacion = _delegacionNombreFromRecord(json[key]);
      if (ownerDelegacion != null) return ownerDelegacion;
    }

    return null;
  }

  static String _fallbackUnidadNombre(int id) {
    switch (id) {
      case 1:
        return 'SINIESTROS';
      case 2:
        return 'DELEGACIONES';
      case 3:
        return 'SEGURIDAD VIAL';
      case 4:
        return 'PROTECCION A CARRETERAS';
      case 5:
        return 'PROTECCION A VIALIDADES URBANAS';
      case 6:
        return 'FOMENTO A LA CULTURA VIAL';
      default:
        return 'UNIDAD $id';
    }
  }

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      type: _parseType(json['type']),
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      userName: (json['user_name'] ?? '').toString(),
      resumen: (json['resumen'] ?? '').toString(),
      categoriaNombre: _asNullableString(
        json['categoria_nombre'] ?? json['categoria'] ?? json['category_name'],
      ),
      subcategoriaNombre: _asNullableString(
        json['subcategoria_nombre'] ??
            json['subcategoria'] ??
            json['subcategory_name'],
      ),
      fotoUrl: _asNullableString(
        json['foto_url'] ??
            json['fotoUrl'] ??
            json['photo_url'] ??
            json['image_url'] ??
            json['foto'] ??
            json['foto_path'],
      ),
      createdAt: _parseDate(json['created_at']),
      showUrl: (json['show_url'] == null) ? null : json['show_url'].toString(),
      unidadId: _unidadIdFromJson(json),
      unidadNombre: _unidadNombreFromJson(json),
      delegacionId: _delegacionIdFromJson(json),
      delegacionNombre: _delegacionNombreFromJson(json),
    );
  }
}

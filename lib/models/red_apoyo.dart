class DirectorioRedApoyoPage {
  final List<RedApoyoContact> items;
  final List<RedApoyoRegionGroup> groupedByRegion;
  final int count;
  final int limit;

  const DirectorioRedApoyoPage({
    required this.items,
    required this.groupedByRegion,
    required this.count,
    required this.limit,
  });

  factory DirectorioRedApoyoPage.fromJson(Map<String, dynamic> json) {
    final items = _readList(
      json['data'],
    ).map(RedApoyoContact.fromJson).where((item) => item.id > 0).toList();

    final groups = _readList(json['grouped_by_region'])
        .map(RedApoyoRegionGroup.fromJson)
        .where((group) => group.items.isNotEmpty)
        .toList();

    final meta = _readMap(json['meta']);

    return DirectorioRedApoyoPage(
      items: items,
      groupedByRegion: groups.isEmpty
          ? RedApoyoRegionGroup.fromContacts(items)
          : groups,
      count: _readInt(meta['count']) ?? items.length,
      limit: _readInt(meta['limit']) ?? items.length,
    );
  }
}

class DirectorioRedApoyoMeta {
  final List<RedApoyoRegion> regiones;
  final Map<String, String> nivelesGobierno;
  final Map<String, String> tiposApoyo;

  const DirectorioRedApoyoMeta({
    required this.regiones,
    required this.nivelesGobierno,
    required this.tiposApoyo,
  });

  const DirectorioRedApoyoMeta.empty()
    : regiones = const <RedApoyoRegion>[],
      nivelesGobierno = const <String, String>{},
      tiposApoyo = const <String, String>{};

  factory DirectorioRedApoyoMeta.fromJson(Map<String, dynamic> json) {
    return DirectorioRedApoyoMeta(
      regiones: _readList(
        json['regiones'],
      ).map(RedApoyoRegion.fromJson).where((item) => item.id > 0).toList(),
      nivelesGobierno: _readStringMap(json['niveles_gobierno']),
      tiposApoyo: _readStringMap(json['tipos_apoyo']),
    );
  }
}

class RedApoyoRegionGroup {
  final String region;
  final List<RedApoyoContact> items;

  const RedApoyoRegionGroup({required this.region, required this.items});

  factory RedApoyoRegionGroup.fromJson(Map<String, dynamic> json) {
    return RedApoyoRegionGroup(
      region: _readText(json['region'], fallback: 'Sin region'),
      items: _readList(
        json['items'],
      ).map(RedApoyoContact.fromJson).where((item) => item.id > 0).toList(),
    );
  }

  static List<RedApoyoRegionGroup> fromContacts(List<RedApoyoContact> items) {
    final buckets = <String, List<RedApoyoContact>>{};
    for (final item in items) {
      final key = item.region.isEmpty ? 'Sin region' : item.region;
      buckets.putIfAbsent(key, () => <RedApoyoContact>[]).add(item);
    }

    return buckets.entries
        .map(
          (entry) => RedApoyoRegionGroup(region: entry.key, items: entry.value),
        )
        .toList();
  }
}

class RedApoyoContact {
  final int id;
  final String region;
  final String nivelGobierno;
  final String tipoApoyo;
  final String tipoApoyoLabel;
  final String institucion;
  final String contacto;
  final String cargo;
  final String telefono;
  final String telefonoSecundario;
  final List<String> telefonos;
  final RedApoyoWhatsApp whatsapp;
  final String direccion;
  final String municipio;
  final String observaciones;
  final int orden;
  final RedApoyoDelegacion? delegacion;
  final RedApoyoDestacamento? destacamento;
  final String updatedAt;

  const RedApoyoContact({
    required this.id,
    required this.region,
    required this.nivelGobierno,
    required this.tipoApoyo,
    required this.tipoApoyoLabel,
    required this.institucion,
    required this.contacto,
    required this.cargo,
    required this.telefono,
    required this.telefonoSecundario,
    required this.telefonos,
    required this.whatsapp,
    required this.direccion,
    required this.municipio,
    required this.observaciones,
    required this.orden,
    required this.delegacion,
    required this.destacamento,
    required this.updatedAt,
  });

  factory RedApoyoContact.fromJson(Map<String, dynamic> json) {
    return RedApoyoContact(
      id: _readInt(json['id']) ?? 0,
      region: _readText(json['region']),
      nivelGobierno: _readText(json['nivel_gobierno']),
      tipoApoyo: _readText(json['tipo_apoyo']),
      tipoApoyoLabel: _readText(
        json['tipo_apoyo_label'] ?? json['tipo_apoyo'],
        fallback: 'Sin tipo',
      ),
      institucion: _readText(json['institucion'], fallback: 'Sin institucion'),
      contacto: _readText(json['contacto']),
      cargo: _readText(json['cargo']),
      telefono: _readText(json['telefono']),
      telefonoSecundario: _readText(json['telefono_secundario']),
      telefonos: _readStringList(json['telefonos']),
      whatsapp: RedApoyoWhatsApp.fromJson(_readMap(json['whatsapp'])),
      direccion: _readText(json['direccion']),
      municipio: _readText(json['municipio']),
      observaciones: _readText(json['observaciones']),
      orden: _readInt(json['orden']) ?? 0,
      delegacion: _readNullableMap(json['delegacion']) == null
          ? null
          : RedApoyoDelegacion.fromJson(_readMap(json['delegacion'])),
      destacamento: _readNullableMap(json['destacamento']) == null
          ? null
          : RedApoyoDestacamento.fromJson(_readMap(json['destacamento'])),
      updatedAt: _readText(json['updated_at']),
    );
  }

  bool get hasPhone =>
      telefono.trim().isNotEmpty || telefonoSecundario.trim().isNotEmpty;

  String get regionLabel => region.trim().isEmpty ? 'Sin region' : region;

  String get nivelLabel =>
      nivelGobierno.trim().isEmpty ? 'Sin nivel' : nivelGobierno;

  String get territorioLabel {
    final delegacionValue = delegacion;
    if (delegacionValue != null) {
      if (delegacionValue.padre != null) {
        return '${delegacionValue.nombre} (${delegacionValue.padre!.nombre})';
      }
      return delegacionValue.nombre;
    }

    final destacamentoValue = destacamento;
    if (destacamentoValue != null) {
      return destacamentoValue.nombre;
    }

    return nivelGobierno == 'Estatal' ? 'General estatal' : 'Sin adscripcion';
  }
}

class RedApoyoWhatsApp {
  final String telefono;
  final String url;
  final String telefonoSecundario;
  final String urlSecundaria;

  const RedApoyoWhatsApp({
    required this.telefono,
    required this.url,
    required this.telefonoSecundario,
    required this.urlSecundaria,
  });

  factory RedApoyoWhatsApp.fromJson(Map<String, dynamic> json) {
    return RedApoyoWhatsApp(
      telefono: _readText(json['telefono']),
      url: _readText(json['url']),
      telefonoSecundario: _readText(json['telefono_secundario']),
      urlSecundaria: _readText(json['url_secundaria']),
    );
  }
}

class RedApoyoRegion {
  final int id;
  final String clave;
  final String nombre;
  final String municipio;
  final List<RedApoyoRegion> hijas;

  const RedApoyoRegion({
    required this.id,
    required this.clave,
    required this.nombre,
    required this.municipio,
    required this.hijas,
  });

  factory RedApoyoRegion.fromJson(Map<String, dynamic> json) {
    return RedApoyoRegion(
      id: _readInt(json['id']) ?? 0,
      clave: _readText(json['clave']),
      nombre: _readText(json['nombre'], fallback: 'Sin nombre'),
      municipio: _readText(json['municipio']),
      hijas: _readList(
        json['hijas'],
      ).map(RedApoyoRegion.fromJson).where((item) => item.id > 0).toList(),
    );
  }
}

class RedApoyoDelegacion {
  final int id;
  final String clave;
  final String nombre;
  final String municipio;
  final bool esHija;
  final RedApoyoDelegacion? padre;

  const RedApoyoDelegacion({
    required this.id,
    required this.clave,
    required this.nombre,
    required this.municipio,
    required this.esHija,
    required this.padre,
  });

  factory RedApoyoDelegacion.fromJson(Map<String, dynamic> json) {
    return RedApoyoDelegacion(
      id: _readInt(json['id']) ?? 0,
      clave: _readText(json['clave']),
      nombre: _readText(json['nombre'], fallback: 'Sin delegacion'),
      municipio: _readText(json['municipio']),
      esHija: _readBool(json['es_hija']),
      padre: _readNullableMap(json['padre']) == null
          ? null
          : RedApoyoDelegacion.fromJson(_readMap(json['padre'])),
    );
  }
}

class RedApoyoDestacamento {
  final int id;
  final String nombre;

  const RedApoyoDestacamento({required this.id, required this.nombre});

  factory RedApoyoDestacamento.fromJson(Map<String, dynamic> json) {
    return RedApoyoDestacamento(
      id: _readInt(json['id']) ?? 0,
      nombre: _readText(json['nombre'], fallback: 'Sin destacamento'),
    );
  }
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == '1' || text == 'true' || text == 'si';
}

String _readText(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic>? _readNullableMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _readList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<String> _readStringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

Map<String, String> _readStringMap(dynamic value) {
  if (value is! Map) return const <String, String>{};
  return value.map(
    (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
  );
}

class ActividadCategoria {
  final int id;
  final String nombre;
  final String? slug;
  final bool requiereFomentoCulturaVial;

  const ActividadCategoria({
    required this.id,
    required this.nombre,
    this.slug,
    this.requiereFomentoCulturaVial = false,
  });

  factory ActividadCategoria.fromJson(Map<String, dynamic> json) {
    return ActividadCategoria(
      id: _asInt(json['id']),
      nombre: (json['nombre'] ?? '').toString().trim(),
      slug: _asNullableString(json['slug']),
      requiereFomentoCulturaVial: _asBool(
        json['requiere_fomento_cultura_vial'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'slug': slug,
    'requiere_fomento_cultura_vial': requiereFomentoCulturaVial,
  };

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final raw = v?.toString().trim().toLowerCase() ?? '';
    return raw == '1' || raw == 'true' || raw == 'si' || raw == 'sí';
  }

  static String? _asNullableString(dynamic v) {
    if (v == null) return null;
    final value = v.toString().trim();
    return value.isEmpty ? null : value;
  }
}

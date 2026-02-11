class ActividadSubcategoria {
  final int id;
  final String nombre;

  const ActividadSubcategoria({required this.id, required this.nombre});

  factory ActividadSubcategoria.fromJson(Map<String, dynamic> json) {
    return ActividadSubcategoria(
      id: _asInt(json['id']),
      nombre: (json['nombre'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre};

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

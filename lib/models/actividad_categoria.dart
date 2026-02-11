class ActividadCategoria {
  final int id;
  final String nombre;

  const ActividadCategoria({required this.id, required this.nombre});

  factory ActividadCategoria.fromJson(Map<String, dynamic> json) {
    return ActividadCategoria(
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

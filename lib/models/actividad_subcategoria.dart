import 'actividad_fomento.dart';

class ActividadSubcategoria {
  final int id;
  final String nombre;
  final List<ActividadFomentoPrograma> programasFomento;

  const ActividadSubcategoria({
    required this.id,
    required this.nombre,
    this.programasFomento = const <ActividadFomentoPrograma>[],
  });

  factory ActividadSubcategoria.fromJson(Map<String, dynamic> json) {
    final programasRaw = json['programas_fomento'];
    return ActividadSubcategoria(
      id: _asInt(json['id']),
      nombre: (json['nombre'] ?? '').toString().trim(),
      programasFomento: programasRaw is List
          ? programasRaw
                .whereType<Map>()
                .map(
                  (item) => ActividadFomentoPrograma.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <ActividadFomentoPrograma>[],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'programas_fomento': programasFomento.map((e) => e.toJson()).toList(),
  };

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

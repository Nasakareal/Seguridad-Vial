import 'actividad_categoria.dart';
import 'actividad_subcategoria.dart';

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

  final ActividadCategoria? categoria;
  final ActividadSubcategoria? subcategoria;

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
    required this.categoria,
    required this.subcategoria,
  });

  factory Actividad.fromJson(Map<String, dynamic> json) {
    final cat = json['categoria'];
    final sub = json['subcategoria'];

    return Actividad(
      id: _asInt(json['id']),
      actividadCategoriaId: _asInt(json['actividad_categoria_id']),
      actividadSubcategoriaId: _asNullableInt(
        json['actividad_subcategoria_id'],
      ),
      nombre: (json['nombre'] ?? '').toString(),
      cantidad: _asInt(json['cantidad']),
      fotoPath:
          _asNullableString(json['foto_path']) ??
          _asNullableString(json['foto_url']) ??
          _asNullableString(json['foto']),
      fotoNombreOriginal: _asNullableString(json['foto_nombre_original']),
      fotoHash: _asNullableString(json['foto_hash']),
      createdAt: _asNullableDate(json['created_at']),
      categoria: (cat is Map)
          ? ActividadCategoria.fromJson(Map<String, dynamic>.from(cat))
          : null,
      subcategoria: (sub is Map)
          ? ActividadSubcategoria.fromJson(Map<String, dynamic>.from(sub))
          : null,
    );
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
    'categoria': categoria?.toJson(),
    'subcategoria': subcategoria?.toJson(),
  };

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static String? _asNullableString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _asNullableDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

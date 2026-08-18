import 'comunicacion.dart';

class ComunicacionDestinatario {
  final int id;
  final int? userId;

  final String? nombre;
  final String? unidad;
  final String? turno;

  final DateTime? leidoAt;
  final DateTime? enteradoAt;

  final Comunicacion? comunicacion;

  const ComunicacionDestinatario({
    required this.id,
    this.userId,
    this.nombre,
    this.unidad,
    this.turno,
    this.leidoAt,
    this.enteradoAt,
    this.comunicacion,
  });

  factory ComunicacionDestinatario.fromJson(Map<String, dynamic> json) {
    return ComunicacionDestinatario(
      id: _toInt(json['id']) ?? 0,
      userId: _toInt(json['user_id']),
      nombre: _nullableString(json['nombre']),
      unidad: _nullableString(json['unidad']),
      turno: _nullableString(json['turno']),
      leidoAt: _toDateTime(json['leido_at']),
      enteradoAt: _toDateTime(json['enterado_at']),
      comunicacion: json['comunicacion'] is Map
          ? Comunicacion.fromJson(
              Map<String, dynamic>.from(json['comunicacion'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'nombre': nombre,
      'unidad': unidad,
      'turno': turno,
      'leido_at': leidoAt?.toIso8601String(),
      'enterado_at': enteradoAt?.toIso8601String(),
      'comunicacion': comunicacion?.toJson(),
    };
  }

  ComunicacionDestinatario copyWith({
    int? id,
    int? userId,
    String? nombre,
    String? unidad,
    String? turno,
    DateTime? leidoAt,
    DateTime? enteradoAt,
    Comunicacion? comunicacion,
  }) {
    return ComunicacionDestinatario(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nombre: nombre ?? this.nombre,
      unidad: unidad ?? this.unidad,
      turno: turno ?? this.turno,
      leidoAt: leidoAt ?? this.leidoAt,
      enteradoAt: enteradoAt ?? this.enteradoAt,
      comunicacion: comunicacion ?? this.comunicacion,
    );
  }

  bool get estaLeido => leidoAt != null;

  bool get estaEnterado => enteradoAt != null;

  bool get estaPendiente => leidoAt == null;

  bool get leidoSinEnterado => leidoAt != null && enteradoAt == null;

  String get estado {
    if (enteradoAt != null) {
      return 'Enterado';
    }

    if (leidoAt != null) {
      return 'Leído';
    }

    return 'Pendiente';
  }

  String get nombreVisible {
    if (nombre != null && nombre!.trim().isNotEmpty) {
      return nombre!.trim();
    }

    return 'Usuario';
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

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    final texto = value.toString().trim();

    if (texto.isEmpty) {
      return null;
    }

    return DateTime.tryParse(texto);
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final texto = value.toString();

    return texto.isEmpty ? null : texto;
  }
}

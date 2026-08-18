import 'comunicacion_adjunto.dart';
import 'comunicacion_usuario.dart';

class Comunicacion {
  final int id;
  final String tipo;
  final String? asunto;
  final String? contenido;
  final String alcance;

  final int remitenteUserId;
  final int? destinatarioUserId;

  final bool requiereEnterado;
  final bool esMio;

  final DateTime? enviadoAt;

  final ComunicacionUsuario? remitente;
  final ComunicacionUsuario? destinatario;

  final ComunicacionReferencia? unidad;
  final ComunicacionReferencia? turno;
  final ComunicacionReferencia? rol;

  final List<ComunicacionAdjunto> adjuntos;

  final int? destinatariosCount;
  final int? leidosCount;
  final int? enteradosCount;

  const Comunicacion({
    required this.id,
    required this.tipo,
    required this.asunto,
    required this.contenido,
    required this.alcance,
    required this.remitenteUserId,
    required this.destinatarioUserId,
    required this.requiereEnterado,
    required this.esMio,
    required this.enviadoAt,
    required this.remitente,
    required this.destinatario,
    required this.unidad,
    required this.turno,
    required this.rol,
    required this.adjuntos,
    this.destinatariosCount,
    this.leidosCount,
    this.enteradosCount,
  });

  factory Comunicacion.fromJson(Map<String, dynamic> json) {
    return Comunicacion(
      id: _toInt(json['id']) ?? 0,
      tipo: json['tipo']?.toString() ?? '',
      asunto: _nullableString(json['asunto']),
      contenido: _nullableString(json['contenido']),
      alcance: json['alcance']?.toString() ?? '',
      remitenteUserId: _toInt(json['remitente_user_id']) ?? 0,
      destinatarioUserId: _toInt(json['destinatario_user_id']),
      requiereEnterado: _toBool(json['requiere_enterado']),
      esMio: _toBool(json['es_mio']),
      enviadoAt: _toDateTime(json['enviado_at']),
      remitente: json['remitente'] is Map
          ? ComunicacionUsuario.fromJson(
              Map<String, dynamic>.from(json['remitente'] as Map),
            )
          : null,
      destinatario: json['destinatario'] is Map
          ? ComunicacionUsuario.fromJson(
              Map<String, dynamic>.from(json['destinatario'] as Map),
            )
          : null,
      unidad: json['unidad'] is Map
          ? ComunicacionReferencia.fromJson(
              Map<String, dynamic>.from(json['unidad'] as Map),
            )
          : null,
      turno: json['turno'] is Map
          ? ComunicacionReferencia.fromJson(
              Map<String, dynamic>.from(json['turno'] as Map),
            )
          : null,
      rol: json['rol'] is Map
          ? ComunicacionReferencia.fromJson(
              Map<String, dynamic>.from(json['rol'] as Map),
            )
          : null,
      adjuntos: json['adjuntos'] is List
          ? (json['adjuntos'] as List)
                .whereType<Map>()
                .map(
                  (item) => ComunicacionAdjunto.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : <ComunicacionAdjunto>[],
      destinatariosCount: _toInt(json['destinatarios_count']),
      leidosCount: _toInt(json['leidos_count']),
      enteradosCount: _toInt(json['enterados_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo,
      'asunto': asunto,
      'contenido': contenido,
      'alcance': alcance,
      'remitente_user_id': remitenteUserId,
      'destinatario_user_id': destinatarioUserId,
      'requiere_enterado': requiereEnterado,
      'es_mio': esMio,
      'enviado_at': enviadoAt?.toIso8601String(),
      'remitente': remitente?.toJson(),
      'destinatario': destinatario?.toJson(),
      'unidad': unidad?.toJson(),
      'turno': turno?.toJson(),
      'rol': rol?.toJson(),
      'adjuntos': adjuntos.map((item) => item.toJson()).toList(),
      'destinatarios_count': destinatariosCount,
      'leidos_count': leidosCount,
      'enterados_count': enteradosCount,
    };
  }

  Comunicacion copyWith({
    int? id,
    String? tipo,
    String? asunto,
    String? contenido,
    String? alcance,
    int? remitenteUserId,
    int? destinatarioUserId,
    bool? requiereEnterado,
    bool? esMio,
    DateTime? enviadoAt,
    ComunicacionUsuario? remitente,
    ComunicacionUsuario? destinatario,
    ComunicacionReferencia? unidad,
    ComunicacionReferencia? turno,
    ComunicacionReferencia? rol,
    List<ComunicacionAdjunto>? adjuntos,
    int? destinatariosCount,
    int? leidosCount,
    int? enteradosCount,
  }) {
    return Comunicacion(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      asunto: asunto ?? this.asunto,
      contenido: contenido ?? this.contenido,
      alcance: alcance ?? this.alcance,
      remitenteUserId: remitenteUserId ?? this.remitenteUserId,
      destinatarioUserId: destinatarioUserId ?? this.destinatarioUserId,
      requiereEnterado: requiereEnterado ?? this.requiereEnterado,
      esMio: esMio ?? this.esMio,
      enviadoAt: enviadoAt ?? this.enviadoAt,
      remitente: remitente ?? this.remitente,
      destinatario: destinatario ?? this.destinatario,
      unidad: unidad ?? this.unidad,
      turno: turno ?? this.turno,
      rol: rol ?? this.rol,
      adjuntos: adjuntos ?? this.adjuntos,
      destinatariosCount: destinatariosCount ?? this.destinatariosCount,
      leidosCount: leidosCount ?? this.leidosCount,
      enteradosCount: enteradosCount ?? this.enteradosCount,
    );
  }

  bool get esMensaje => tipo == 'mensaje';

  bool get esAviso => tipo == 'aviso';

  bool get esOrden => tipo == 'orden';

  bool get tieneTexto => contenido != null && contenido!.trim().isNotEmpty;

  bool get tieneAdjuntos => adjuntos.isNotEmpty;

  bool get tieneImagenes => adjuntos.any((adjunto) => adjunto.esImagen);

  String get titulo {
    if (asunto != null && asunto!.trim().isNotEmpty) {
      return asunto!.trim();
    }

    if (esMensaje) {
      return 'Mensaje directo';
    }

    return 'Comunicación';
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

    final normalized = value.toString().toLowerCase().trim();

    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'si' ||
        normalized == 'sí';
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

    return texto;
  }
}

class ComunicacionReferencia {
  final int id;
  final String nombre;

  const ComunicacionReferencia({required this.id, required this.nombre});

  factory ComunicacionReferencia.fromJson(Map<String, dynamic> json) {
    return ComunicacionReferencia(
      id: Comunicacion._toInt(json['id']) ?? 0,
      nombre: json['nombre']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'nombre': nombre};
  }

  @override
  String toString() => nombre;
}

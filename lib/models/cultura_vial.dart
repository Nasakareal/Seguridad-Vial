class CulturaVialSala {
  final int id;
  final String codigo;
  final String nombre;
  final String juegoSlug;
  final String estado;
  final bool abierta;
  final int participantesCount;
  final String joinPayload;
  final String? qrUrl;
  final List<CulturaVialParticipante> participantes;

  const CulturaVialSala({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.juegoSlug,
    required this.estado,
    required this.abierta,
    required this.participantesCount,
    required this.joinPayload,
    this.qrUrl,
    this.participantes = const <CulturaVialParticipante>[],
  });

  factory CulturaVialSala.fromJson(Map<String, dynamic> json) {
    final participantesRaw = json['participantes'];
    final participantes = participantesRaw is List
        ? participantesRaw
              .whereType<Map>()
              .map(
                (item) => CulturaVialParticipante.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const <CulturaVialParticipante>[];

    return CulturaVialSala(
      id: _asInt(json['id']),
      codigo: (json['codigo'] ?? '').toString(),
      nombre: (json['nombre'] ?? 'Clase de Cultura Vial').toString(),
      juegoSlug: (json['juego_slug'] ?? 'ciudad_segura').toString(),
      estado: (json['estado'] ?? 'abierta').toString(),
      abierta: _asBool(json['abierta']) || json['estado'] == 'abierta',
      participantesCount: _asInt(json['participantes_count']),
      joinPayload: (json['join_payload'] ?? '').toString(),
      qrUrl: (json['qr_url'] ?? '').toString().trim().isEmpty
          ? null
          : json['qr_url'].toString(),
      participantes: participantes,
    );
  }
}

class CulturaVialParticipante {
  final int id;
  final String nombre;
  final String joinToken;
  final int mejorPuntaje;
  final int intentos;
  final List<CulturaVialIntento> intentosRecientes;

  const CulturaVialParticipante({
    required this.id,
    required this.nombre,
    required this.joinToken,
    required this.mejorPuntaje,
    required this.intentos,
    this.intentosRecientes = const <CulturaVialIntento>[],
  });

  factory CulturaVialParticipante.fromJson(Map<String, dynamic> json) {
    final intentosRaw = json['intentos_recientes'];
    final intentos = intentosRaw is List
        ? intentosRaw
              .whereType<Map>()
              .map(
                (item) => CulturaVialIntento.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const <CulturaVialIntento>[];

    return CulturaVialParticipante(
      id: _asInt(json['id']),
      nombre: (json['nombre'] ?? '').toString(),
      joinToken: (json['join_token'] ?? '').toString(),
      mejorPuntaje: _asInt(json['mejor_puntaje']),
      intentos: _asInt(json['intentos']),
      intentosRecientes: intentos,
    );
  }
}

class CulturaVialIntento {
  final int id;
  final int puntaje;
  final int aciertos;
  final int errores;
  final int duracionSegundos;

  const CulturaVialIntento({
    required this.id,
    required this.puntaje,
    required this.aciertos,
    required this.errores,
    required this.duracionSegundos,
  });

  factory CulturaVialIntento.fromJson(Map<String, dynamic> json) {
    return CulturaVialIntento(
      id: _asInt(json['id']),
      puntaje: _asInt(json['puntaje']),
      aciertos: _asInt(json['aciertos']),
      errores: _asInt(json['errores']),
      duracionSegundos: _asInt(json['duracion_segundos']),
    );
  }
}

class CulturaVialJoinResult {
  final CulturaVialSala sala;
  final CulturaVialParticipante participante;

  const CulturaVialJoinResult({required this.sala, required this.participante});

  factory CulturaVialJoinResult.fromJson(Map<String, dynamic> json) {
    final source = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    return CulturaVialJoinResult(
      sala: CulturaVialSala.fromJson(
        Map<String, dynamic>.from(source['sala'] as Map),
      ),
      participante: CulturaVialParticipante.fromJson(
        Map<String, dynamic>.from(source['participante'] as Map),
      ),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  final raw = (value ?? '').toString().trim().toLowerCase();
  return raw == '1' || raw == 'true' || raw == 'si' || raw == 'sí';
}

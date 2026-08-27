class SemaforoNode {
  final String id, name, location, route;
  final String primaryStreet, secondaryStreet;
  final String activePlan, scheduleStart, scheduleEnd, scheduleStatus;
  final double? latitude, longitude;
  final DateTime? lastSeen;
  final bool online;
  const SemaforoNode({
    required this.id,
    required this.name,
    required this.location,
    required this.route,
    required this.online,
    this.primaryStreet = '',
    this.secondaryStreet = '',
    this.activePlan = '',
    this.scheduleStart = '',
    this.scheduleEnd = '',
    this.scheduleStatus = '',
    this.latitude,
    this.longitude,
    this.lastSeen,
  });

  factory SemaforoNode.fromJson(Map<String, dynamic> json) {
    double? number(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    DateTime? date(dynamic value) => DateTime.tryParse(value?.toString() ?? '');

    return SemaforoNode(
      id: (json['node_id'] ?? json['id'] ?? '').toString(),
      name: (json['nombre'] ?? json['name'] ?? 'Semáforo').toString(),
      location: (json['ubicacion'] ?? json['location'] ?? '').toString(),
      route: (json['ruta'] ?? json['route'] ?? '').toString(),
      primaryStreet: (json['vialidad_principal'] ?? json['street1'] ?? '')
          .toString(),
      secondaryStreet: (json['vialidad_transversal'] ?? json['street2'] ?? '')
          .toString(),
      activePlan: (json['plan_activo'] ?? json['plan'] ?? '').toString(),
      scheduleStart: (json['horario_inicio'] ?? json['start'] ?? '').toString(),
      scheduleEnd: (json['horario_fin'] ?? json['end'] ?? '').toString(),
      scheduleStatus: (json['horario_estado'] ?? json['schedule'] ?? '')
          .toString(),
      latitude: number(json['latitud'] ?? json['latitude']),
      longitude: number(json['longitud'] ?? json['longitude']),
      lastSeen: date(json['ultimo_contacto_at'] ?? json['last_seen']),
      online:
          json['online'] == true ||
          json['estado'] == 'online' ||
          json['estado_operativo'] == 'online',
    );
  }

  String get streets => [
    primaryStreet,
    secondaryStreet,
  ].where((value) => value.trim().isNotEmpty).join(' / ');
}

enum PriorityRequestStatus { pending, acknowledged, active, cleared, rejected }

class SemaforoPriorityRequest {
  final String id, nodeId, message;
  final PriorityRequestStatus status;
  const SemaforoPriorityRequest({
    required this.id,
    required this.nodeId,
    required this.status,
    this.message = '',
  });
  bool get confirmed =>
      status == PriorityRequestStatus.acknowledged ||
      status == PriorityRequestStatus.active;

  factory SemaforoPriorityRequest.fromJson(Map<String, dynamic> json) {
    final raw = (json['estado'] ?? json['status'] ?? 'pending')
        .toString()
        .toLowerCase();
    final status = switch (raw) {
      'acknowledged' || 'confirmada' => PriorityRequestStatus.acknowledged,
      'active' || 'activa' => PriorityRequestStatus.active,
      'clear' || 'cleared' || 'finalizada' => PriorityRequestStatus.cleared,
      'rejected' || 'rechazada' => PriorityRequestStatus.rejected,
      _ => PriorityRequestStatus.pending,
    };
    return SemaforoPriorityRequest(
      id: (json['id'] ?? json['request_id'] ?? '').toString(),
      nodeId: (json['node_id'] ?? '').toString(),
      status: status,
      message: (json['mensaje'] ?? json['message'] ?? '').toString(),
    );
  }
}

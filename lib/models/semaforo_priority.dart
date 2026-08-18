class SemaforoNode {
  final String id, name, location, route;
  final bool online;
  const SemaforoNode({
    required this.id,
    required this.name,
    required this.location,
    required this.route,
    required this.online,
  });

  factory SemaforoNode.fromJson(Map<String, dynamic> json) => SemaforoNode(
    id: (json['node_id'] ?? json['id'] ?? '').toString(),
    name: (json['nombre'] ?? json['name'] ?? 'Semáforo').toString(),
    location: (json['ubicacion'] ?? json['location'] ?? '').toString(),
    route: (json['ruta'] ?? json['route'] ?? '').toString(),
    online: json['online'] == true || json['estado'] == 'online',
  );
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

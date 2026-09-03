enum TrafficLightColor { red, yellow, green, unknown }

TrafficLightColor trafficLightColorFromJson(Object? raw) {
  return switch (raw?.toString().trim().toLowerCase()) {
    'red' || 'rojo' => TrafficLightColor.red,
    'yellow' || 'amber' || 'ambar' || 'ámbar' => TrafficLightColor.yellow,
    'green' || 'verde' => TrafficLightColor.green,
    _ => TrafficLightColor.unknown,
  };
}

class TrafficControllerPlan {
  final String movementAName;
  final String movementBName;
  final int greenASeconds;
  final int yellowASeconds;
  final int allRedAToBSeconds;
  final int greenBSeconds;
  final int yellowBSeconds;
  final int allRedBToASeconds;

  const TrafficControllerPlan({
    this.movementAName = 'Semáforo A',
    this.movementBName = 'Semáforo B',
    this.greenASeconds = 30,
    this.yellowASeconds = 3,
    this.allRedAToBSeconds = 2,
    this.greenBSeconds = 30,
    this.yellowBSeconds = 3,
    this.allRedBToASeconds = 2,
  });

  factory TrafficControllerPlan.fromJson(Map<String, dynamic> json) {
    int seconds(String key, int fallback) =>
        int.tryParse('${json[key] ?? ''}') ?? fallback;

    return TrafficControllerPlan(
      movementAName: _text(json['movement_a_name'], 'Semáforo A'),
      movementBName: _text(json['movement_b_name'], 'Semáforo B'),
      greenASeconds: seconds('green_a_seconds', 30),
      yellowASeconds: seconds('yellow_a_seconds', 3),
      allRedAToBSeconds: seconds('all_red_a_to_b_seconds', 2),
      greenBSeconds: seconds('green_b_seconds', 30),
      yellowBSeconds: seconds('yellow_b_seconds', 3),
      allRedBToASeconds: seconds('all_red_b_to_a_seconds', 2),
    );
  }

  int get cycleSeconds =>
      greenASeconds +
      yellowASeconds +
      allRedAToBSeconds +
      greenBSeconds +
      yellowBSeconds +
      allRedBToASeconds;

  String? validate() {
    if (movementAName.trim().isEmpty || movementBName.trim().isEmpty) {
      return 'Asigna un nombre a los dos movimientos.';
    }
    if (movementAName.length > 40 || movementBName.length > 40) {
      return 'Los nombres no pueden superar 40 caracteres.';
    }
    if (greenASeconds < 5 ||
        greenASeconds > 180 ||
        greenBSeconds < 5 ||
        greenBSeconds > 180) {
      return 'Cada verde debe durar entre 5 y 180 segundos.';
    }
    if (yellowASeconds < 2 ||
        yellowASeconds > 10 ||
        yellowBSeconds < 2 ||
        yellowBSeconds > 10) {
      return 'Cada ámbar debe durar entre 2 y 10 segundos.';
    }
    if (allRedAToBSeconds < 1 ||
        allRedAToBSeconds > 10 ||
        allRedBToASeconds < 1 ||
        allRedBToASeconds > 10) {
      return 'Cada intervalo de todo rojo debe durar entre 1 y 10 segundos.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'movement_a_name': movementAName.trim(),
    'movement_b_name': movementBName.trim(),
    'green_a_seconds': greenASeconds,
    'yellow_a_seconds': yellowASeconds,
    'all_red_a_to_b_seconds': allRedAToBSeconds,
    'green_b_seconds': greenBSeconds,
    'yellow_b_seconds': yellowBSeconds,
    'all_red_b_to_a_seconds': allRedBToASeconds,
  };

  static String _text(Object? raw, String fallback) {
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }
}

class TrafficControllerNodeStatus {
  final String name;
  final TrafficLightColor color;
  final bool online;
  final int remainingSeconds;

  const TrafficControllerNodeStatus({
    required this.name,
    required this.color,
    required this.online,
    required this.remainingSeconds,
  });

  factory TrafficControllerNodeStatus.fromJson(
    Map<String, dynamic> json, {
    required String fallbackName,
  }) {
    return TrafficControllerNodeStatus(
      name: TrafficControllerPlan._text(json['name'], fallbackName),
      color: trafficLightColorFromJson(json['color']),
      online: json['online'] == true,
      remainingSeconds: int.tryParse('${json['remaining_seconds'] ?? ''}') ?? 0,
    );
  }
}

class TrafficControllerStatus {
  final bool running;
  final bool peerLinked;
  final bool emergencyAllRed;
  final String mode;
  final String phase;
  final String fault;
  final int remainingSeconds;
  final int sequence;
  final TrafficControllerPlan plan;
  final TrafficControllerNodeStatus nodeA;
  final TrafficControllerNodeStatus nodeB;

  const TrafficControllerStatus({
    required this.running,
    required this.peerLinked,
    required this.emergencyAllRed,
    required this.mode,
    required this.phase,
    required this.fault,
    required this.remainingSeconds,
    required this.sequence,
    required this.plan,
    required this.nodeA,
    required this.nodeB,
  });

  factory TrafficControllerStatus.fromJson(Map<String, dynamic> json) {
    final planRaw = json['plan'];
    final plan = planRaw is Map
        ? TrafficControllerPlan.fromJson(Map<String, dynamic>.from(planRaw))
        : const TrafficControllerPlan();
    Map<String, dynamic> map(Object? raw) =>
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};

    return TrafficControllerStatus(
      running: json['running'] == true,
      peerLinked: json['peer_linked'] == true,
      emergencyAllRed: json['emergency_all_red'] == true,
      mode: TrafficControllerPlan._text(json['mode'], 'desconocido'),
      phase: TrafficControllerPlan._text(json['phase'], 'Sin fase'),
      fault: json['fault']?.toString().trim() ?? '',
      remainingSeconds: int.tryParse('${json['remaining_seconds'] ?? ''}') ?? 0,
      sequence: int.tryParse('${json['sequence'] ?? ''}') ?? 0,
      plan: plan,
      nodeA: TrafficControllerNodeStatus.fromJson(
        map(json['node_a']),
        fallbackName: plan.movementAName,
      ),
      nodeB: TrafficControllerNodeStatus.fromJson(
        map(json['node_b']),
        fallbackName: plan.movementBName,
      ),
    );
  }
}

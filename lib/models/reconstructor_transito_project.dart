import 'dart:math' as math;

double _number(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _integer(Object? value, int fallback) =>
    _number(value, fallback.toDouble()).round();

double _clamp(Object? value, double min, double max, [double fallback = 0]) {
  return _number(value, fallback).clamp(min, max).toDouble();
}

String reconstructorId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(99999)}';

class ReconstructorMetadata {
  ReconstructorMetadata({
    this.name = 'Hecho de tránsito sin título',
    this.hypothesis = 'Hipótesis A',
    this.duration = 10,
    this.pixelsPerMeter = 20,
  });

  String name;
  String hypothesis;
  double duration;
  double pixelsPerMeter;

  factory ReconstructorMetadata.fromJson(Map<String, dynamic>? json) {
    final value = json ?? const <String, dynamic>{};
    return ReconstructorMetadata(
      name: (value['name'] ?? 'Hecho de tránsito sin título').toString(),
      hypothesis: (value['hypothesis'] ?? 'Hipótesis A').toString(),
      duration: _clamp(value['duration'], 2, 120, 10),
      pixelsPerMeter: _clamp(value['pixelsPerMeter'], 2, 100, 20),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'hypothesis': hypothesis,
    'duration': duration,
    'pixelsPerMeter': pixelsPerMeter,
    'mode': 'illustrative',
  };
}

class ReconstructorCurve {
  ReconstructorCurve({
    this.startX = -15,
    this.startY = 4,
    this.control1X = -10,
    this.control1Y = -10,
    this.control2X = 10,
    this.control2Y = -10,
    this.endX = 15,
    this.endY = 4,
  });

  double startX;
  double startY;
  double control1X;
  double control1Y;
  double control2X;
  double control2Y;
  double endX;
  double endY;

  factory ReconstructorCurve.fromJson(Map<String, dynamic>? json) {
    final value = json ?? const <String, dynamic>{};
    return ReconstructorCurve(
      startX: _clamp(value['startX'], -200, 200, -15),
      startY: _clamp(value['startY'], -200, 200, 4),
      control1X: _clamp(value['control1X'], -200, 200, -10),
      control1Y: _clamp(value['control1Y'], -200, 200, -10),
      control2X: _clamp(value['control2X'], -200, 200, 10),
      control2Y: _clamp(value['control2Y'], -200, 200, -10),
      endX: _clamp(value['endX'], -200, 200, 15),
      endY: _clamp(value['endY'], -200, 200, 4),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'startX': startX,
    'startY': startY,
    'control1X': control1X,
    'control1Y': control1Y,
    'control2X': control2X,
    'control2Y': control2Y,
    'endX': endX,
    'endY': endY,
  };
}

class ReconstructorRoad {
  ReconstructorRoad({
    required this.id,
    this.type = 'straight',
    this.name = 'Calle',
    this.x = 600,
    this.y = 350,
    this.lengthMeters = 40,
    this.laneWidthMeters = 3.5,
    this.lanes = 2,
    this.rotation = 0,
    this.direction = 'two_way',
    this.centerLine = 'solid',
    this.leftEdge = 'none',
    this.rightEdge = 'none',
    this.surface = 'asphalt',
    ReconstructorCurve? curve,
  }) : curve = curve ?? ReconstructorCurve();

  String id;
  String type;
  String name;
  double x;
  double y;
  double lengthMeters;
  double laneWidthMeters;
  int lanes;
  double rotation;
  String direction;
  String centerLine;
  String leftEdge;
  String rightEdge;
  String surface;
  ReconstructorCurve curve;

  factory ReconstructorRoad.fromJson(Map<String, dynamic> json, int index) {
    final direction = json['direction'] == 'two_way' ? 'two_way' : 'one_way';
    var lanes = _integer(json['lanes'], 2).clamp(1, 12);
    if (direction == 'two_way' && lanes.isOdd) lanes++;
    const surfaces = <String>{
      'asphalt',
      'concrete',
      'pavers',
      'cobblestone',
      'dirt',
      'gravel',
      'natural',
    };
    final surface = json['surface']?.toString() ?? 'asphalt';
    return ReconstructorRoad(
      id: json['id']?.toString() ?? reconstructorId('road'),
      type: json['type'] == 'curve' ? 'curve' : 'straight',
      name: (json['name'] ?? 'Calle ${index + 1}').toString(),
      x: _clamp(json['x'], -10000, 10000, 600),
      y: _clamp(json['y'], -10000, 10000, 350),
      lengthMeters: _clamp(json['lengthMeters'], 3, 200, 40),
      laneWidthMeters: _clamp(json['laneWidthMeters'], 2, 8, 3.5),
      lanes: lanes,
      rotation: _clamp(json['rotation'], -180, 180),
      direction: direction,
      centerLine:
          const {'solid', 'dashed', 'double_solid'}.contains(json['centerLine'])
          ? json['centerLine'].toString()
          : 'solid',
      leftEdge: const {'none', 'sidewalk', 'median'}.contains(json['leftEdge'])
          ? json['leftEdge'].toString()
          : 'none',
      rightEdge:
          const {'none', 'sidewalk', 'median'}.contains(json['rightEdge'])
          ? json['rightEdge'].toString()
          : 'none',
      surface: surfaces.contains(surface) ? surface : 'asphalt',
      curve: ReconstructorCurve.fromJson(
        json['curve'] is Map
            ? Map<String, dynamic>.from(json['curve'] as Map)
            : null,
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'name': name,
    'x': x,
    'y': y,
    'lengthMeters': lengthMeters,
    'laneWidthMeters': laneWidthMeters,
    'lanes': lanes,
    'rotation': rotation,
    'direction': direction,
    'centerLine': centerLine,
    'leftEdge': leftEdge,
    'rightEdge': rightEdge,
    'surface': surface,
    'curve': curve.toJson(),
  };
}

class ReconstructorKeyframe {
  ReconstructorKeyframe({
    required this.time,
    required this.x,
    required this.y,
    this.rotation = 0,
    this.rotationManual = false,
  });

  double time;
  double x;
  double y;
  double rotation;
  bool rotationManual;

  factory ReconstructorKeyframe.fromJson(
    Map<String, dynamic> json,
    double duration,
  ) => ReconstructorKeyframe(
    time: _clamp(json['time'], 0, duration),
    x: _clamp(json['x'], -10000, 10000),
    y: _clamp(json['y'], -10000, 10000),
    rotation: _number(json['rotation'], 0),
    rotationManual: json['rotationManual'] == true,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'time': time,
    'x': x,
    'y': y,
    'rotation': rotation,
    if (rotationManual) 'rotationManual': true,
  };
}

class ReconstructorActor {
  ReconstructorActor({
    required this.id,
    required this.type,
    required this.name,
    required this.color,
    this.speedKmh = 0,
    List<ReconstructorKeyframe>? keyframes,
  }) : keyframes = keyframes ?? <ReconstructorKeyframe>[];

  String id;
  String type;
  String name;
  int color;
  double speedKmh;
  List<ReconstructorKeyframe> keyframes;

  factory ReconstructorActor.fromJson(
    Map<String, dynamic> json,
    int index,
    double duration,
  ) {
    const types = <String>{
      'automovil',
      'motocicleta',
      'camioneta',
      'camion',
      'bicicleta',
      'peaton',
    };
    final type = types.contains(json['type'])
        ? json['type'].toString()
        : 'automovil';
    final frames =
        (json['keyframes'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (item) => ReconstructorKeyframe.fromJson(
                Map<String, dynamic>.from(item),
                duration,
              ),
            )
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    return ReconstructorActor(
      id: json['id']?.toString() ?? reconstructorId('actor'),
      type: type,
      name: (json['name'] ?? '${actorLabel(type)} ${index + 1}').toString(),
      color: parseHexColor(json['color']?.toString(), actorDefaultColor(type)),
      speedKmh: _clamp(json['speedKmh'], 0, 300),
      keyframes: frames,
    );
  }

  ReconstructorKeyframe? positionAt(double time) {
    if (keyframes.isEmpty) return null;
    final frames = [...keyframes]..sort((a, b) => a.time.compareTo(b.time));
    if (time <= frames.first.time) return frames.first;
    if (time >= frames.last.time) return frames.last;
    for (var index = 0; index < frames.length - 1; index++) {
      final from = frames[index];
      final to = frames[index + 1];
      if (time < from.time || time > to.time) continue;
      final progress = (time - from.time) / math.max(.001, to.time - from.time);
      final delta = ((to.rotation - from.rotation + 540) % 360) - 180;
      return ReconstructorKeyframe(
        time: time,
        x: from.x + ((to.x - from.x) * progress),
        y: from.y + ((to.y - from.y) * progress),
        rotation: from.rotation + (delta * progress),
      );
    }
    return frames.first;
  }

  ReconstructorKeyframe upsert(
    double time,
    double x,
    double y, {
    double? rotation,
    bool manualRotation = false,
  }) {
    final rounded = (time * 100).round() / 100;
    ReconstructorKeyframe? frame;
    for (final candidate in keyframes) {
      if ((candidate.time - rounded).abs() < .015) frame = candidate;
    }
    if (frame == null) {
      frame = ReconstructorKeyframe(
        time: rounded,
        x: x,
        y: y,
        rotation: rotation ?? 0,
        rotationManual: manualRotation,
      );
      keyframes.add(frame);
    } else {
      frame.x = x;
      frame.y = y;
      if (!frame.rotationManual || manualRotation) {
        frame.rotation = rotation ?? frame.rotation;
      }
      if (manualRotation) frame.rotationManual = true;
    }
    keyframes.sort((a, b) => a.time.compareTo(b.time));
    recalculateRotations();
    return frame;
  }

  void recalculateRotations() {
    for (var index = 0; index < keyframes.length; index++) {
      final frame = keyframes[index];
      if (frame.rotationManual || keyframes.length < 2) continue;
      final from = index < keyframes.length - 1 ? frame : keyframes[index - 1];
      final to = index < keyframes.length - 1 ? keyframes[index + 1] : frame;
      if (from.x != to.x || from.y != to.y) {
        frame.rotation =
            math.atan2(to.y - from.y, to.x - from.x) * 180 / math.pi;
      }
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'name': name,
    'image': '',
    'color': colorHex(color),
    'speedKmh': speedKmh,
    'keyframes': keyframes.map((item) => item.toJson()).toList(),
  };
}

class ReconstructorEvent {
  ReconstructorEvent({
    required this.id,
    required this.code,
    required this.x,
    required this.y,
    required this.time,
    required this.description,
  });

  String id;
  String code;
  double x;
  double y;
  double time;
  String description;

  factory ReconstructorEvent.fromJson(
    Map<String, dynamic> json,
    double duration,
  ) {
    final code = eventLabels.containsKey(json['code'])
        ? json['code'].toString()
        : 'PI';
    return ReconstructorEvent(
      id: json['id']?.toString() ?? reconstructorId('event'),
      code: code,
      x: _clamp(json['x'], -10000, 10000),
      y: _clamp(json['y'], -10000, 10000),
      time: _clamp(json['time'], 0, duration),
      description: (json['description'] ?? eventLabels[code]!).toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'code': code,
    'x': x,
    'y': y,
    'time': time,
    'description': description,
  };
}

class ReconstructorProject {
  ReconstructorProject({
    ReconstructorMetadata? metadata,
    List<ReconstructorRoad>? roads,
    Map<String, bool>? layers,
    List<ReconstructorActor>? actors,
    List<ReconstructorEvent>? events,
  }) : metadata = metadata ?? ReconstructorMetadata(),
       roads = roads ?? <ReconstructorRoad>[],
       layers =
           layers ??
           <String, bool>{
             'road': true,
             'actors': true,
             'paths': true,
             'events': true,
             'grid': true,
           },
       actors = actors ?? <ReconstructorActor>[],
       events = events ?? <ReconstructorEvent>[];

  ReconstructorMetadata metadata;
  List<ReconstructorRoad> roads;
  Map<String, bool> layers;
  List<ReconstructorActor> actors;
  List<ReconstructorEvent> events;

  factory ReconstructorProject.fromJson(Map<String, dynamic> json) {
    final metadata = ReconstructorMetadata.fromJson(
      json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
    final scene = json['scene'] is Map
        ? Map<String, dynamic>.from(json['scene'] as Map)
        : const <String, dynamic>{};
    final roadsJson = scene['roads'] as List? ?? const <dynamic>[];
    final actorsJson = json['actors'] as List? ?? const <dynamic>[];
    final eventsJson = json['events'] as List? ?? const <dynamic>[];
    final project = ReconstructorProject(
      metadata: metadata,
      roads: <ReconstructorRoad>[
        for (var index = 0; index < roadsJson.length; index++)
          if (roadsJson[index] is Map)
            ReconstructorRoad.fromJson(
              Map<String, dynamic>.from(roadsJson[index] as Map),
              index,
            ),
      ],
      actors: <ReconstructorActor>[
        for (var index = 0; index < actorsJson.length; index++)
          if (actorsJson[index] is Map)
            ReconstructorActor.fromJson(
              Map<String, dynamic>.from(actorsJson[index] as Map),
              index,
              metadata.duration,
            ),
      ],
      events: eventsJson
          .whereType<Map>()
          .map(
            (item) => ReconstructorEvent.fromJson(
              Map<String, dynamic>.from(item),
              metadata.duration,
            ),
          )
          .toList(),
    );
    if (json['layers'] is Map) {
      for (final entry in (json['layers'] as Map).entries) {
        if (project.layers.containsKey(entry.key.toString())) {
          project.layers[entry.key.toString()] = entry.value != false;
        }
      }
    }
    return project;
  }

  factory ReconstructorProject.demo() {
    final first = ReconstructorActor(
      id: reconstructorId('actor'),
      type: 'automovil',
      name: 'Vehículo 1',
      color: 0xFFEF4444,
      speedKmh: 48,
      keyframes: <ReconstructorKeyframe>[
        ReconstructorKeyframe(time: 0, x: 120, y: 420),
        ReconstructorKeyframe(time: 2.4, x: 360, y: 420),
        ReconstructorKeyframe(time: 4.4, x: 570, y: 420),
        ReconstructorKeyframe(time: 5, x: 650, y: 410, rotation: -8),
        ReconstructorKeyframe(time: 7.4, x: 850, y: 340, rotation: -28),
      ],
    )..recalculateRotations();
    final second = ReconstructorActor(
      id: reconstructorId('actor'),
      type: 'motocicleta',
      name: 'Vehículo 2',
      color: 0xFF38BDF8,
      speedKmh: 38,
      keyframes: <ReconstructorKeyframe>[
        ReconstructorKeyframe(time: 0, x: 650, y: 650, rotation: -90),
        ReconstructorKeyframe(time: 3.2, x: 650, y: 525, rotation: -90),
        ReconstructorKeyframe(time: 5, x: 650, y: 410, rotation: -90),
        ReconstructorKeyframe(time: 6.8, x: 705, y: 310, rotation: -48),
        ReconstructorKeyframe(time: 8.5, x: 775, y: 270, rotation: -18),
      ],
    );
    return ReconstructorProject(
      metadata: ReconstructorMetadata(
        name: 'Ejemplo · Cruce con punto de conflicto',
      ),
      roads: <ReconstructorRoad>[
        ReconstructorRoad(
          id: reconstructorId('road'),
          name: 'Avenida principal',
          x: 600,
          y: 420,
          lengthMeters: 60,
          rotation: 0,
          leftEdge: 'sidewalk',
          rightEdge: 'sidewalk',
        ),
        ReconstructorRoad(
          id: reconstructorId('road'),
          name: 'Calle transversal',
          x: 650,
          y: 350,
          lengthMeters: 38,
          rotation: 90,
          surface: 'concrete',
          centerLine: 'dashed',
        ),
      ],
      actors: <ReconstructorActor>[first, second],
      events: <ReconstructorEvent>[
        ReconstructorEvent(
          id: reconstructorId('event'),
          code: 'PR',
          x: 360,
          y: 420,
          time: 2.4,
          description: 'El conductor identifica el riesgo.',
        ),
        ReconstructorEvent(
          id: reconstructorId('event'),
          code: 'IF',
          x: 470,
          y: 420,
          time: 3.4,
          description: 'Inicio estimado de frenado.',
        ),
        ReconstructorEvent(
          id: reconstructorId('event'),
          code: 'PMC',
          x: 650,
          y: 410,
          time: 4.8,
          description: 'Convergencia máxima de trayectorias.',
        ),
        ReconstructorEvent(
          id: reconstructorId('event'),
          code: 'PI',
          x: 650,
          y: 410,
          time: 5,
          description: 'Punto de impacto ilustrativo.',
        ),
        ReconstructorEvent(
          id: reconstructorId('event'),
          code: 'PF',
          x: 850,
          y: 340,
          time: 7.4,
          description: 'Posición final del vehículo 1.',
        ),
      ],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 1,
    'metadata': metadata.toJson(),
    'scene': <String, dynamic>{
      'roads': roads.map((item) => item.toJson()).toList(),
    },
    'layers': layers,
    'actors': actors.map((item) => item.toJson()).toList(),
    'events': events.map((item) => item.toJson()).toList(),
  };
}

const Map<String, String> eventLabels = <String, String>{
  'PR': 'Punto de reacción',
  'IF': 'Inicio de frenado',
  'PE': 'Punto de evasión',
  'PMC': 'Punto máximo de conflicto',
  'PI': 'Punto de impacto',
  'PF': 'Posición final',
};

String actorLabel(String type) =>
    const <String, String>{
      'automovil': 'Automóvil',
      'motocicleta': 'Motocicleta',
      'camioneta': 'Camioneta',
      'camion': 'Camión',
      'bicicleta': 'Bicicleta',
      'peaton': 'Peatón',
    }[type] ??
    'Automóvil';

int actorDefaultColor(String type) =>
    const <String, int>{
      'automovil': 0xFFEF4444,
      'motocicleta': 0xFF38BDF8,
      'camioneta': 0xFFF59E0B,
      'camion': 0xFFA78BFA,
      'bicicleta': 0xFF22C58B,
      'peaton': 0xFFF97316,
    }[type] ??
    0xFFEF4444;

int parseHexColor(String? value, int fallback) {
  final clean = (value ?? '').replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean)) return fallback;
  return 0xFF000000 | int.parse(clean, radix: 16);
}

String colorHex(int color) =>
    '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

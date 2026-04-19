import 'dart:convert';

class CroquisElement {
  CroquisElement({
    required this.id,
    required this.tipo,
    required this.x,
    required this.y,
    this.rotacion = 0,
    this.seleccionado = false,
    this.ancho,
    this.alto,
    this.categoria,
    this.subtipo,
    this.src,
    this.clave,
    this.contenido,
    this.fontSize,
    this.fontFamily,
    this.largo,
    this.anchoCarril,
    this.carriles,
    this.radioInterno,
    this.angulo,
    this.largoHorizontal,
    this.largoVertical,
    this.largoBase,
    this.largoBrazo,
    this.radioIsla,
    this.largoAcceso,
  });

  final String id;
  final String tipo;
  double x;
  double y;
  double rotacion;
  bool seleccionado;

  double? ancho;
  double? alto;
  String? categoria;
  String? subtipo;
  String? src;
  String? clave;
  String? contenido;
  double? fontSize;
  String? fontFamily;
  double? largo;
  double? anchoCarril;
  int? carriles;
  double? radioInterno;
  double? angulo;
  double? largoHorizontal;
  double? largoVertical;
  double? largoBase;
  double? largoBrazo;
  double? radioIsla;
  double? largoAcceso;

  CroquisElement copy() {
    return CroquisElement(
      id: id,
      tipo: tipo,
      x: x,
      y: y,
      rotacion: rotacion,
      seleccionado: seleccionado,
      ancho: ancho,
      alto: alto,
      categoria: categoria,
      subtipo: subtipo,
      src: src,
      clave: clave,
      contenido: contenido,
      fontSize: fontSize,
      fontFamily: fontFamily,
      largo: largo,
      anchoCarril: anchoCarril,
      carriles: carriles,
      radioInterno: radioInterno,
      angulo: angulo,
      largoHorizontal: largoHorizontal,
      largoVertical: largoVertical,
      largoBase: largoBase,
      largoBrazo: largoBrazo,
      radioIsla: radioIsla,
      largoAcceso: largoAcceso,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'tipo': tipo,
      'x': x,
      'y': y,
      'rotacion': rotacion,
    };

    void put(String key, Object? value) {
      if (value == null) return;
      json[key] = value;
    }

    if (tipo == 'carro') {
      put('ancho', ancho);
      put('alto', alto);
    } else if (tipo == 'vehiculo') {
      put('categoria', categoria);
      put('subtipo', subtipo);
      put('src', src);
      put('ancho', ancho);
      put('alto', alto);
    } else if (tipo == 'icono') {
      put('clave', clave);
      put('src', src);
      put('ancho', ancho);
      put('alto', alto);
    } else if (tipo == 'texto') {
      put('contenido', contenido);
      put('fontSize', fontSize);
      put('fontFamily', fontFamily);
      put('ancho', ancho);
      put('alto', alto);
    } else if (tipo == 'calle') {
      put('largo', largo);
      put('anchoCarril', anchoCarril);
      put('carriles', carriles);
    } else if (tipo == 'curva') {
      put('radioInterno', radioInterno);
      put('anchoCarril', anchoCarril);
      put('carriles', carriles);
      put('angulo', angulo);
    } else if (tipo == 'cruce') {
      put('largo', largo);
      put('largoHorizontal', largoHorizontal);
      put('largoVertical', largoVertical);
      put('anchoCarril', anchoCarril);
      put('carriles', carriles);
    } else if (tipo == 'entronque') {
      put('largoBase', largoBase);
      put('largoBrazo', largoBrazo);
      put('anchoCarril', anchoCarril);
      put('carriles', carriles);
    } else if (tipo == 'glorieta') {
      put('radioIsla', radioIsla);
      put('anchoCarril', anchoCarril);
      put('carriles', carriles);
      put('largoAcceso', largoAcceso);
    }

    return json;
  }

  static String serialize(List<CroquisElement> elementos) {
    return jsonEncode(elementos.map((el) => el.toJson()).toList());
  }
}

class CroquisModels {
  static int _nextId = 1;

  static String _uid() => 'croquis_${_nextId++}';

  static void setNextIdFromExisting(List<CroquisElement> elementos) {
    var maxId = 0;

    for (final el in elementos) {
      final match = RegExp(r'(\d+)$').firstMatch(el.id);
      if (match == null) continue;
      final id = int.tryParse(match.group(1) ?? '') ?? 0;
      if (id > maxId) maxId = id;
    }

    _nextId = maxId + 1;
  }

  static CroquisElement carro({double x = 200, double y = 200}) {
    return CroquisElement(
      id: _uid(),
      tipo: 'carro',
      x: x,
      y: y,
      ancho: 60,
      alto: 30,
    );
  }

  static CroquisElement vehiculo({
    double x = 200,
    double y = 200,
    String categoria = 'automovil',
    String subtipo = 'sedan',
    String src = '',
    double ancho = 90,
    double alto = 50,
  }) {
    return CroquisElement(
      id: _uid(),
      tipo: 'vehiculo',
      x: x,
      y: y,
      categoria: categoria,
      subtipo: subtipo,
      src: src,
      ancho: ancho,
      alto: alto,
    );
  }

  static CroquisElement icono({
    double x = 200,
    double y = 200,
    String clave = '',
    String src = '',
    double ancho = 36,
    double alto = 36,
  }) {
    return CroquisElement(
      id: _uid(),
      tipo: 'icono',
      x: x,
      y: y,
      clave: clave,
      src: src,
      ancho: ancho,
      alto: alto,
    );
  }

  static CroquisElement texto({
    double x = 250,
    double y = 250,
    String contenido = 'Texto',
  }) {
    return CroquisElement(
      id: _uid(),
      tipo: 'texto',
      x: x,
      y: y,
      contenido: contenido,
      fontSize: 20,
      fontFamily: 'Arial',
      ancho: _textWidth(contenido, 20),
      alto: 28,
    );
  }

  static CroquisElement calle({double x = 250, double y = 200}) {
    return CroquisElement(
      id: _uid(),
      tipo: 'calle',
      x: x,
      y: y,
      largo: 260,
      anchoCarril: 28,
      carriles: 1,
    );
  }

  static CroquisElement curva({double x = 320, double y = 240}) {
    return CroquisElement(
      id: _uid(),
      tipo: 'curva',
      x: x,
      y: y,
      radioInterno: 45,
      anchoCarril: 28,
      carriles: 1,
      angulo: 90,
    );
  }

  static CroquisElement cruce({double x = 320, double y = 240}) {
    return CroquisElement(
      id: _uid(),
      tipo: 'cruce',
      x: x,
      y: y,
      largo: 220,
      largoHorizontal: 220,
      largoVertical: 220,
      anchoCarril: 28,
      carriles: 1,
    );
  }

  static CroquisElement entronque({double x = 320, double y = 240}) {
    return CroquisElement(
      id: _uid(),
      tipo: 'entronque',
      x: x,
      y: y,
      largoBase: 220,
      largoBrazo: 140,
      anchoCarril: 28,
      carriles: 1,
    );
  }

  static CroquisElement glorieta({double x = 420, double y = 260}) {
    return CroquisElement(
      id: _uid(),
      tipo: 'glorieta',
      x: x,
      y: y,
      radioIsla: 40,
      anchoCarril: 24,
      carriles: 1,
      largoAcceso: 140,
    );
  }

  static List<CroquisElement> deserialize(dynamic raw) {
    try {
      dynamic data = raw;
      if (data is String && data.trim().isNotEmpty) {
        data = jsonDecode(data);
      }
      if (data is Map && data['json_dibujo'] != null) {
        data = data['json_dibujo'];
        if (data is String && data.trim().isNotEmpty) {
          data = jsonDecode(data);
        }
      }
      if (data is! List) return <CroquisElement>[];

      final elementos = data
          .whereType<Map>()
          .map((item) => normalize(Map<String, dynamic>.from(item)))
          .whereType<CroquisElement>()
          .toList();
      setNextIdFromExisting(elementos);
      return elementos;
    } catch (_) {
      return <CroquisElement>[];
    }
  }

  static CroquisElement? normalize(Map<String, dynamic> raw) {
    final tipo = (raw['tipo'] ?? '').toString();
    if (tipo.isEmpty) return null;

    final base = CroquisElement(
      id: (raw['id'] ?? _uid()).toString(),
      tipo: tipo,
      x: _toDouble(raw['x'], 200),
      y: _toDouble(raw['y'], 200),
      rotacion: _toDouble(raw['rotacion'] ?? raw['r'], 0),
    );

    if (tipo == 'carro') {
      base.ancho = _toDouble(raw['ancho'] ?? raw['w'], 60);
      base.alto = _toDouble(raw['alto'] ?? raw['h'], 30);
      return base;
    }

    if (tipo == 'vehiculo') {
      base.categoria = (raw['categoria'] ?? 'automovil').toString();
      base.subtipo = (raw['subtipo'] ?? 'sedan').toString();
      base.src = (raw['src'] ?? '').toString();
      base.ancho = _toDouble(raw['ancho'] ?? raw['w'], 90);
      base.alto = _toDouble(raw['alto'] ?? raw['h'], 50);
      return base;
    }

    if (tipo == 'icono') {
      base.clave = (raw['clave'] ?? raw['nombre'] ?? '').toString();
      base.src = (raw['src'] ?? '').toString();
      base.ancho = _toDouble(raw['ancho'] ?? raw['w'], 36);
      base.alto = _toDouble(raw['alto'] ?? raw['h'], 36);
      return base;
    }

    if (tipo == 'texto') {
      final contenido = (raw['contenido'] ?? raw['texto'] ?? 'Texto')
          .toString();
      final fontSize = _toDouble(raw['fontSize'], 20);
      base.contenido = contenido;
      base.fontSize = fontSize;
      base.fontFamily = (raw['fontFamily'] ?? 'Arial').toString();
      base.ancho = _toDouble(
        raw['ancho'] ?? raw['w'],
        _textWidth(contenido, fontSize),
      );
      base.alto = _toDouble(raw['alto'] ?? raw['h'], fontSize + 8);
      return base;
    }

    if (tipo == 'calle') {
      base.largo = _toDouble(raw['largo'] ?? raw['w'], 260);
      base.anchoCarril = _toDouble(raw['anchoCarril'], 28);
      base.carriles = _toInt(raw['carriles'], 1).clamp(1, 12).toInt();
      return base;
    }

    if (tipo == 'curva') {
      base.radioInterno = _toDouble(raw['radioInterno'] ?? raw['radio'], 45);
      base.anchoCarril = _toDouble(raw['anchoCarril'], 28);
      base.carriles = _toInt(raw['carriles'], 1).clamp(1, 12).toInt();
      base.angulo = _toDouble(raw['angulo'], 90).clamp(30, 180).toDouble();
      return base;
    }

    if (tipo == 'cruce') {
      final largo = _toDouble(
        raw['largo'] ??
            raw['size'] ??
            raw['largoHorizontal'] ??
            raw['largoVertical'],
        220,
      );
      final largoHorizontal = _toDouble(
        raw['largoHorizontal'] ?? raw['w'],
        largo,
      );
      final largoVertical = _toDouble(raw['largoVertical'] ?? raw['h'], largo);
      base.largo = [
        largo,
        largoHorizontal,
        largoVertical,
      ].reduce((value, next) => value > next ? value : next);
      base.largoHorizontal = largoHorizontal;
      base.largoVertical = largoVertical;
      base.anchoCarril = _toDouble(raw['anchoCarril'], 28);
      base.carriles = _toInt(raw['carriles'], 1).clamp(1, 12).toInt();
      return base;
    }

    if (tipo == 'entronque') {
      base.largoBase = _toDouble(raw['largoBase'] ?? raw['size'], 220);
      base.largoBrazo = _toDouble(raw['largoBrazo'], 140);
      base.anchoCarril = _toDouble(raw['anchoCarril'], 28);
      base.carriles = _toInt(raw['carriles'], 1).clamp(1, 12).toInt();
      return base;
    }

    if (tipo == 'glorieta') {
      base.radioIsla = _toDouble(raw['radioIsla'], 40);
      base.anchoCarril = _toDouble(raw['anchoCarril'], 24);
      base.carriles = _toInt(raw['carriles'], 1).clamp(1, 12).toInt();
      base.largoAcceso = _toDouble(raw['largoAcceso'], 140);
      return base;
    }

    return null;
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? fallback;
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  static double _textWidth(String text, double fontSize) {
    return (text.trim().isEmpty ? 40 : text.trim().length * fontSize * 0.62)
        .clamp(40, 420)
        .toDouble();
  }
}

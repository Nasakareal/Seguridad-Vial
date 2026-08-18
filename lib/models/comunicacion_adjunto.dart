class ComunicacionAdjunto {
  final int id;
  final String tipo;
  final String? nombreOriginal;
  final String? mimeType;
  final int? tamanoBytes;
  final int? ancho;
  final int? alto;
  final String url;

  const ComunicacionAdjunto({
    required this.id,
    required this.tipo,
    required this.nombreOriginal,
    required this.mimeType,
    required this.tamanoBytes,
    required this.ancho,
    required this.alto,
    required this.url,
  });

  factory ComunicacionAdjunto.fromJson(Map<String, dynamic> json) {
    return ComunicacionAdjunto(
      id: _toInt(json['id']) ?? 0,
      tipo: json['tipo']?.toString() ?? '',
      nombreOriginal: _nullableString(json['nombre_original']),
      mimeType: _nullableString(json['mime_type']),
      tamanoBytes: _toInt(json['tamano_bytes']),
      ancho: _toInt(json['ancho']),
      alto: _toInt(json['alto']),
      url: json['url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo,
      'nombre_original': nombreOriginal,
      'mime_type': mimeType,
      'tamano_bytes': tamanoBytes,
      'ancho': ancho,
      'alto': alto,
      'url': url,
    };
  }

  ComunicacionAdjunto copyWith({
    int? id,
    String? tipo,
    String? nombreOriginal,
    String? mimeType,
    int? tamanoBytes,
    int? ancho,
    int? alto,
    String? url,
  }) {
    return ComunicacionAdjunto(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      nombreOriginal: nombreOriginal ?? this.nombreOriginal,
      mimeType: mimeType ?? this.mimeType,
      tamanoBytes: tamanoBytes ?? this.tamanoBytes,
      ancho: ancho ?? this.ancho,
      alto: alto ?? this.alto,
      url: url ?? this.url,
    );
  }

  bool get esImagen {
    if (tipo == 'imagen') {
      return true;
    }

    if (mimeType == null) {
      return false;
    }

    return mimeType!.toLowerCase().startsWith('image/');
  }

  bool get tieneUrl => url.trim().isNotEmpty;

  bool get esHorizontal {
    if (ancho == null || alto == null) {
      return false;
    }

    return ancho! > alto!;
  }

  bool get esVertical {
    if (ancho == null || alto == null) {
      return false;
    }

    return alto! > ancho!;
  }

  bool get esCuadrada {
    if (ancho == null || alto == null) {
      return false;
    }

    return ancho == alto;
  }

  double? get relacionAspecto {
    if (ancho == null || alto == null || alto == 0) {
      return null;
    }

    return ancho! / alto!;
  }

  String get nombre {
    if (nombreOriginal != null && nombreOriginal!.trim().isNotEmpty) {
      return nombreOriginal!.trim();
    }

    return 'Imagen';
  }

  String get tamanoLegible {
    if (tamanoBytes == null) {
      return '';
    }

    final bytes = tamanoBytes!;

    if (bytes < 1024) {
      return '$bytes B';
    }

    final kb = bytes / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final mb = kb / 1024;

    return '${mb.toStringAsFixed(1)} MB';
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

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    return value.toString();
  }
}

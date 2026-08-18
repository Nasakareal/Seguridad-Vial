import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/comunicacion.dart';
import '../models/comunicacion_destinatario.dart';
import '../models/comunicacion_usuario.dart';

class ComunicacionService {
  final String baseUrl;
  final http.Client _client;

  String token;

  ComunicacionService({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String get _base {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  Map<String, String> get _headers {
    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  void actualizarToken(String nuevoToken) {
    token = nuevoToken;
  }

  Future<ComunicacionesBandeja> obtenerBandeja({
    int perPage = 20,
    int recibidasPage = 1,
    int enviadasPage = 1,
  }) async {
    final uri = Uri.parse('$_base/comunicaciones').replace(
      queryParameters: {
        'per_page': perPage.toString(),
        'recibidas_page': recibidasPage.toString(),
        'enviadas_page': enviadasPage.toString(),
      },
    );

    final response = await _client.get(uri, headers: _headers);

    final json = _procesarRespuesta(response);

    return ComunicacionesBandeja.fromJson(json);
  }

  Future<List<ComunicacionUsuario>> obtenerDestinatarios({
    String busqueda = '',
    int? unidadId,
    int? turnoId,
  }) async {
    final query = <String, String>{};

    if (busqueda.trim().isNotEmpty) {
      query['q'] = busqueda.trim();
    }

    if (unidadId != null) {
      query['unidad_id'] = unidadId.toString();
    }

    if (turnoId != null) {
      query['turno_id'] = turnoId.toString();
    }

    final uri = Uri.parse(
      '$_base/comunicaciones/destinatarios',
    ).replace(queryParameters: query.isEmpty ? null : query);

    final response = await _client.get(uri, headers: _headers);

    final json = _procesarRespuesta(response);

    final usuarios = json['usuarios'];

    if (usuarios is! List) {
      return [];
    }

    return usuarios
        .whereType<Map>()
        .map(
          (item) =>
              ComunicacionUsuario.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<ComunicacionCatalogos> obtenerCatalogos() async {
    final uri = Uri.parse('$_base/comunicaciones/catalogos');

    final response = await _client.get(uri, headers: _headers);

    final json = _procesarRespuesta(response);

    return ComunicacionCatalogos.fromJson(json);
  }

  Future<ComunicacionNoLeidas> obtenerNoLeidas() async {
    final uri = Uri.parse('$_base/comunicaciones/no-leidas/count');

    final response = await _client.get(uri, headers: _headers);

    final json = _procesarRespuesta(response);

    return ComunicacionNoLeidas.fromJson(json);
  }

  Future<ConversacionComunicacion> obtenerConversacion(int userId) async {
    final uri = Uri.parse('$_base/comunicaciones/conversacion/$userId');

    final response = await _client.get(uri, headers: _headers);

    final json = _procesarRespuesta(response);

    return ConversacionComunicacion.fromJson(json);
  }

  Future<ComunicacionDetalle> obtenerComunicacion(int comunicacionId) async {
    final uri = Uri.parse('$_base/comunicaciones/$comunicacionId');

    final response = await _client.get(uri, headers: _headers);

    final json = _procesarRespuesta(response);

    return ComunicacionDetalle.fromJson(json);
  }

  Future<Comunicacion> enviarMensaje({
    required int destinatarioUserId,
    String contenido = '',
    List<XFile> imagenes = const [],
  }) {
    return enviarComunicacion(
      tipo: 'mensaje',
      alcance: 'usuario',
      destinatarioUserId: destinatarioUserId,
      contenido: contenido,
      requiereEnterado: false,
      imagenes: imagenes,
    );
  }

  Future<Comunicacion> enviarComunicacion({
    required String tipo,
    required String alcance,
    String? asunto,
    String contenido = '',
    int? unidadId,
    int? turnoId,
    int? roleId,
    int? destinatarioUserId,
    bool requiereEnterado = false,
    List<XFile> imagenes = const [],
  }) async {
    if (tipo == 'mensaje' && contenido.trim().isEmpty && imagenes.isEmpty) {
      throw const ComunicacionApiException(
        mensaje: 'Debes escribir un mensaje o adjuntar al menos una imagen.',
      );
    }

    if (imagenes.length > 10) {
      throw const ComunicacionApiException(
        mensaje: 'Puedes enviar un máximo de 10 imágenes.',
      );
    }

    final uri = Uri.parse('$_base/comunicaciones');

    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll(_headers);

    request.fields['tipo'] = tipo;
    request.fields['alcance'] = alcance;
    request.fields['contenido'] = contenido;
    request.fields['requiere_enterado'] = requiereEnterado ? '1' : '0';

    if (asunto != null && asunto.trim().isNotEmpty) {
      request.fields['asunto'] = asunto.trim();
    }

    if (unidadId != null) {
      request.fields['unidad_id'] = unidadId.toString();
    }

    if (turnoId != null) {
      request.fields['turno_id'] = turnoId.toString();
    }

    if (roleId != null) {
      request.fields['role_id'] = roleId.toString();
    }

    if (destinatarioUserId != null) {
      request.fields['destinatario_user_id'] = destinatarioUserId.toString();
    }

    for (final imagen in imagenes) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imagenes[]',
          imagen.path,
          filename: imagen.name,
        ),
      );
    }

    final streamedResponse = await _client.send(request);

    final body = await streamedResponse.stream.bytesToString();

    final json = _procesarStreamedResponse(streamedResponse.statusCode, body);

    final data = json['comunicacion'];

    if (data is! Map) {
      throw const ComunicacionApiException(
        mensaje: 'El servidor no devolvió la comunicación creada.',
      );
    }

    return Comunicacion.fromJson(Map<String, dynamic>.from(data));
  }

  Future<ComunicacionEstadoLectura> marcarLeido(int comunicacionId) async {
    final uri = Uri.parse('$_base/comunicaciones/$comunicacionId/leer');

    final response = await _client.post(uri, headers: _headers);

    final json = _procesarRespuesta(response);

    return ComunicacionEstadoLectura.fromJson(json);
  }

  Future<ComunicacionEstadoLectura> marcarEnterado(int comunicacionId) async {
    final uri = Uri.parse('$_base/comunicaciones/$comunicacionId/enterado');

    final response = await _client.post(uri, headers: _headers);

    final json = _procesarRespuesta(response);

    return ComunicacionEstadoLectura.fromJson(json);
  }

  Future<Uint8List> descargarAdjunto(String url) async {
    final uri = _resolverUrl(url);

    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'image/*'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ComunicacionApiException(
        statusCode: response.statusCode,
        mensaje: 'No fue posible cargar la imagen.',
      );
    }

    return response.bodyBytes;
  }

  Uri _resolverUrl(String url) {
    final parsed = Uri.tryParse(url);

    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      return parsed;
    }

    if (url.startsWith('/')) {
      final base = Uri.parse(_base);

      return Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: url,
      );
    }

    return Uri.parse('$_base/$url');
  }

  Map<String, dynamic> _procesarRespuesta(http.Response response) {
    return _procesarStreamedResponse(response.statusCode, response.body);
  }

  Map<String, dynamic> _procesarStreamedResponse(int statusCode, String body) {
    dynamic decoded;

    if (body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        decoded = null;
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return {};
    }

    String mensaje = 'Ocurrió un error al comunicarse con el servidor.';

    Map<String, dynamic>? errores;

    if (decoded is Map) {
      final data = Map<String, dynamic>.from(decoded);

      final serverMessage = data['message'];

      if (serverMessage != null && serverMessage.toString().trim().isNotEmpty) {
        mensaje = serverMessage.toString().trim();
      }

      if (data['errors'] is Map) {
        errores = Map<String, dynamic>.from(data['errors'] as Map);

        final primerError = _primerErrorValidacion(errores);

        if (primerError != null) {
          mensaje = primerError;
        }
      }
    }

    throw ComunicacionApiException(
      statusCode: statusCode,
      mensaje: mensaje,
      errores: errores,
    );
  }

  String? _primerErrorValidacion(Map<String, dynamic> errores) {
    for (final value in errores.values) {
      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }

      if (value != null) {
        return value.toString();
      }
    }

    return null;
  }

  void dispose() {
    _client.close();
  }
}

class ComunicacionCatalogos {
  final Map<String, bool> capacidades;

  final List<ComunicacionCatalogoItem> unidades;
  final List<ComunicacionCatalogoItem> turnos;
  final List<ComunicacionCatalogoItem> roles;

  const ComunicacionCatalogos({
    required this.capacidades,
    required this.unidades,
    required this.turnos,
    required this.roles,
  });

  factory ComunicacionCatalogos.fromJson(Map<String, dynamic> json) {
    final capacidades = <String, bool>{};

    if (json['capacidades'] is Map) {
      final mapa = Map<String, dynamic>.from(json['capacidades'] as Map);

      for (final entry in mapa.entries) {
        capacidades[entry.key] = _toBool(entry.value);
      }
    }

    return ComunicacionCatalogos(
      capacidades: capacidades,
      unidades: _leerCatalogo(json['unidades']),
      turnos: _leerCatalogo(json['turnos']),
      roles: _leerCatalogo(json['roles']),
    );
  }

  bool permite(String capacidad) {
    return capacidades[capacidad] == true;
  }

  static List<ComunicacionCatalogoItem> _leerCatalogo(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => ComunicacionCatalogoItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.id > 0 && item.nombre.trim().isNotEmpty)
        .toList();
  }
}

class ComunicacionCatalogoItem {
  final int id;
  final String nombre;

  const ComunicacionCatalogoItem({required this.id, required this.nombre});

  factory ComunicacionCatalogoItem.fromJson(Map<String, dynamic> json) {
    return ComunicacionCatalogoItem(
      id: _toInt(json['id']) ?? 0,
      nombre:
          _toNullableString(json['nombre']) ??
          _toNullableString(json['name']) ??
          '',
    );
  }

  @override
  String toString() {
    return nombre;
  }
}

class ComunicacionesBandeja {
  final List<ComunicacionDestinatario> recibidas;
  final List<Comunicacion> enviadas;

  final int noLeidas;

  final Map<String, bool> capacidades;

  final PaginacionComunicacion paginacionRecibidas;
  final PaginacionComunicacion paginacionEnviadas;

  const ComunicacionesBandeja({
    required this.recibidas,
    required this.enviadas,
    required this.noLeidas,
    required this.capacidades,
    required this.paginacionRecibidas,
    required this.paginacionEnviadas,
  });

  factory ComunicacionesBandeja.fromJson(Map<String, dynamic> json) {
    final recibidasJson = json['recibidas'] is Map
        ? Map<String, dynamic>.from(json['recibidas'] as Map)
        : <String, dynamic>{};

    final enviadasJson = json['enviadas'] is Map
        ? Map<String, dynamic>.from(json['enviadas'] as Map)
        : <String, dynamic>{};

    final recibidasData = recibidasJson['data'] is List
        ? recibidasJson['data'] as List
        : const [];

    final enviadasData = enviadasJson['data'] is List
        ? enviadasJson['data'] as List
        : const [];

    final capacidades = <String, bool>{};

    if (json['capacidades'] is Map) {
      final mapa = Map<String, dynamic>.from(json['capacidades'] as Map);

      for (final entry in mapa.entries) {
        capacidades[entry.key] = _toBool(entry.value);
      }
    }

    return ComunicacionesBandeja(
      recibidas: recibidasData
          .whereType<Map>()
          .map(
            (item) => ComunicacionDestinatario.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      enviadas: enviadasData
          .whereType<Map>()
          .map((item) => Comunicacion.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      noLeidas: _toInt(json['no_leidas']) ?? 0,
      capacidades: capacidades,
      paginacionRecibidas: PaginacionComunicacion.fromJson(recibidasJson),
      paginacionEnviadas: PaginacionComunicacion.fromJson(enviadasJson),
    );
  }
}

class ConversacionComunicacion {
  final ComunicacionUsuario usuario;
  final List<Comunicacion> mensajes;
  final int noLeidas;

  const ConversacionComunicacion({
    required this.usuario,
    required this.mensajes,
    required this.noLeidas,
  });

  factory ConversacionComunicacion.fromJson(Map<String, dynamic> json) {
    final usuarioJson = json['usuario'] is Map
        ? Map<String, dynamic>.from(json['usuario'] as Map)
        : <String, dynamic>{};

    final mensajesJson = json['mensajes'] is List
        ? json['mensajes'] as List
        : const [];

    return ConversacionComunicacion(
      usuario: ComunicacionUsuario.fromJson(usuarioJson),
      mensajes: mensajesJson
          .whereType<Map>()
          .map((item) => Comunicacion.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      noLeidas: _toInt(json['no_leidas']) ?? 0,
    );
  }
}

class ComunicacionDetalle {
  final Comunicacion comunicacion;
  final bool esRemitente;

  final ComunicacionDestinatario? registroDestinatario;

  final List<ComunicacionDestinatario> destinatarios;

  final int noLeidas;

  const ComunicacionDetalle({
    required this.comunicacion,
    required this.esRemitente,
    required this.registroDestinatario,
    required this.destinatarios,
    required this.noLeidas,
  });

  factory ComunicacionDetalle.fromJson(Map<String, dynamic> json) {
    final comunicacionJson = json['comunicacion'] is Map
        ? Map<String, dynamic>.from(json['comunicacion'] as Map)
        : <String, dynamic>{};

    ComunicacionDestinatario? registro;

    if (json['registro_destinatario'] is Map) {
      registro = ComunicacionDestinatario.fromJson(
        Map<String, dynamic>.from(json['registro_destinatario'] as Map),
      );
    }

    final destinatariosJson = json['destinatarios'] is List
        ? json['destinatarios'] as List
        : const [];

    return ComunicacionDetalle(
      comunicacion: Comunicacion.fromJson(comunicacionJson),
      esRemitente: _toBool(json['es_remitente']),
      registroDestinatario: registro,
      destinatarios: destinatariosJson
          .whereType<Map>()
          .map(
            (item) => ComunicacionDestinatario.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      noLeidas: _toInt(json['no_leidas']) ?? 0,
    );
  }
}

class ComunicacionNoLeidas {
  final int count;

  final int? ultimoDestinatarioId;
  final int? ultimoComunicacionId;

  final String? ultimoTipo;
  final String? ultimoAsunto;
  final String? ultimoRemitente;

  final DateTime? ultimoEnviadoAt;

  const ComunicacionNoLeidas({
    required this.count,
    this.ultimoDestinatarioId,
    this.ultimoComunicacionId,
    this.ultimoTipo,
    this.ultimoAsunto,
    this.ultimoRemitente,
    this.ultimoEnviadoAt,
  });

  factory ComunicacionNoLeidas.fromJson(Map<String, dynamic> json) {
    return ComunicacionNoLeidas(
      count: _toInt(json['count']) ?? 0,
      ultimoDestinatarioId: _toInt(json['ultimo_destinatario_id']),
      ultimoComunicacionId: _toInt(json['ultimo_comunicacion_id']),
      ultimoTipo: _toNullableString(json['ultimo_tipo']),
      ultimoAsunto: _toNullableString(json['ultimo_asunto']),
      ultimoRemitente: _toNullableString(json['ultimo_remitente']),
      ultimoEnviadoAt: _toDateTime(json['ultimo_enviado_at']),
    );
  }
}

class ComunicacionEstadoLectura {
  final bool ok;

  final DateTime? leidoAt;
  final DateTime? enteradoAt;

  final int noLeidas;

  const ComunicacionEstadoLectura({
    required this.ok,
    this.leidoAt,
    this.enteradoAt,
    required this.noLeidas,
  });

  factory ComunicacionEstadoLectura.fromJson(Map<String, dynamic> json) {
    return ComunicacionEstadoLectura(
      ok: _toBool(json['ok']),
      leidoAt: _toDateTime(json['leido_at']),
      enteradoAt: _toDateTime(json['enterado_at']),
      noLeidas: _toInt(json['no_leidas']) ?? 0,
    );
  }
}

class PaginacionComunicacion {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PaginacionComunicacion({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory PaginacionComunicacion.fromJson(Map<String, dynamic> json) {
    return PaginacionComunicacion(
      currentPage: _toInt(json['current_page']) ?? 1,
      lastPage: _toInt(json['last_page']) ?? 1,
      perPage: _toInt(json['per_page']) ?? 20,
      total: _toInt(json['total']) ?? 0,
    );
  }

  bool get tieneSiguiente {
    return currentPage < lastPage;
  }
}

class ComunicacionApiException implements Exception {
  final int? statusCode;
  final String mensaje;

  final Map<String, dynamic>? errores;

  const ComunicacionApiException({
    this.statusCode,
    required this.mensaje,
    this.errores,
  });

  @override
  String toString() {
    return mensaje;
  }
}

int? _toInt(dynamic value) {
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

bool _toBool(dynamic value) {
  if (value == null) {
    return false;
  }

  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final texto = value.toString().trim().toLowerCase();

  return texto == '1' ||
      texto == 'true' ||
      texto == 'yes' ||
      texto == 'si' ||
      texto == 'sí';
}

String? _toNullableString(dynamic value) {
  if (value == null) {
    return null;
  }

  final texto = value.toString().trim();

  return texto.isEmpty ? null : texto;
}

DateTime? _toDateTime(dynamic value) {
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

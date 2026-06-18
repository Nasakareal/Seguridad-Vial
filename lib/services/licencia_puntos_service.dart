import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/licencias/licencia_qr_parser.dart';
import 'auth_service.dart';

class LicenciaPuntosService {
  static const int saldoLegalMaximo = 12;

  static String get _base => '${AuthService.baseUrl}/licencias-puntos';

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    return <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static LicenciaQrData parseLicencia(String raw) {
    return LicenciaQrParser.parse(raw);
  }

  static Future<LicenciaPuntosMeta> meta() async {
    final resp = await http
        .get(Uri.parse('$_base/meta'), headers: await _headers(json: false))
        .timeout(const Duration(seconds: 15));

    final raw = _decode(resp);
    final data = _map(raw['data']);
    return LicenciaPuntosMeta.fromJson(data);
  }

  static Future<LicenciaPuntoCuenta> buscarPorNumero(
    String numeroLicencia,
  ) async {
    final numero = numeroLicencia.trim();
    if (numero.isEmpty) {
      throw Exception('Captura o escanea el número de licencia.');
    }

    final resp = await http
        .get(
          Uri.parse('$_base/numero/${Uri.encodeComponent(numero)}'),
          headers: await _headers(json: false),
        )
        .timeout(const Duration(seconds: 15));

    final raw = _decode(resp);
    return LicenciaPuntoCuenta.fromJson(_map(raw['data']));
  }

  static Future<LicenciaPuntoCuenta> registrarInfraccion({
    int? cuentaId,
    required String numeroLicencia,
    String? titularNombre,
    String? tipoLicencia,
    String? telefono,
    required int infraccionId,
    int? hechoId,
    String? referencia,
    String? descripcion,
  }) async {
    final body = <String, dynamic>{
      if (cuentaId != null && cuentaId > 0) 'cuenta_id': cuentaId,
      if (cuentaId == null || cuentaId <= 0) 'numero_licencia': numeroLicencia,
      if ((titularNombre ?? '').trim().isNotEmpty)
        'titular_nombre': titularNombre!.trim(),
      if ((tipoLicencia ?? '').trim().isNotEmpty)
        'tipo_licencia': tipoLicencia!.trim(),
      if ((telefono ?? '').trim().isNotEmpty) 'telefono': telefono!.trim(),
      'infraccion_id': infraccionId,
      if (hechoId != null && hechoId > 0) 'hecho_id': hechoId,
      if ((referencia ?? '').trim().isNotEmpty)
        'referencia': referencia!.trim(),
      if ((descripcion ?? '').trim().isNotEmpty)
        'descripcion': descripcion!.trim(),
    };

    final resp = await http
        .post(
          Uri.parse('$_base/infracciones'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    final raw = _decode(resp);
    return LicenciaPuntoCuenta.fromJson(_map(raw['data']));
  }

  static Future<LicenciaPuntoCuenta> acreditarCapacitacion({
    required int cuentaId,
    required int puntos,
    String? referencia,
    String? descripcion,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_base/$cuentaId/capacitacion'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            'puntos': puntos,
            if ((referencia ?? '').trim().isNotEmpty)
              'referencia': referencia!.trim(),
            if ((descripcion ?? '').trim().isNotEmpty)
              'descripcion': descripcion!.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    final raw = _decode(resp);
    return LicenciaPuntoCuenta.fromJson(_map(raw['data']));
  }

  static Map<String, dynamic> _decode(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        cleanExceptionMessage(_backendError(resp.body, resp.statusCode)),
      );
    }

    final raw = jsonDecode(resp.body);
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw Exception('Respuesta inválida del servidor.');
  }

  static String cleanExceptionMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Ocurrió un error inesperado.';
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  static String _backendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        final errors = raw['errors'];
        if (errors is Map) {
          final messages = <String>[];
          errors.forEach((_, value) {
            if (value is List && value.isNotEmpty) {
              messages.add(value.first.toString());
            }
          });
          if (messages.isNotEmpty) return messages.join('\n');
        }

        final message = (raw['message'] ?? '').toString().trim();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static int _int(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    final text = (value ?? '').toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'si' || text == 'sí';
  }

  static String _string(dynamic value) {
    return (value ?? '').toString().trim();
  }

  static int _saldoLegal(dynamic value) {
    final parsed = _int(value, saldoLegalMaximo);
    return parsed < saldoLegalMaximo ? saldoLegalMaximo : parsed;
  }

  static int _saldoActualLegal(Map<String, dynamic> json) {
    final movimientos = json['movimientos'];
    if (movimientos is List) {
      var saldo = saldoLegalMaximo;
      for (final item in movimientos) {
        if (item is Map) {
          saldo += _int(item['puntos']);
        }
      }
      return saldo.clamp(0, saldoLegalMaximo).toInt();
    }

    final rawMax = _int(json['saldo_maximo'], saldoLegalMaximo);
    final max = _saldoLegal(rawMax);
    final rawSaldo = _int(json['saldo_actual'], max);
    final adjusted = rawMax > 0 && rawMax < saldoLegalMaximo
        ? rawSaldo + (saldoLegalMaximo - rawMax)
        : rawSaldo;

    return adjusted.clamp(0, max).toInt();
  }
}

class LicenciaPuntosMeta {
  final int saldoInicial;
  final int saldoMaximo;
  final int mesesRecuperacionTiempo;
  final LicenciaPuntosAbilities abilities;
  final List<LicenciaPuntoInfraccion> infracciones;

  const LicenciaPuntosMeta({
    required this.saldoInicial,
    required this.saldoMaximo,
    required this.mesesRecuperacionTiempo,
    required this.abilities,
    required this.infracciones,
  });

  factory LicenciaPuntosMeta.fromJson(Map<String, dynamic> json) {
    final list = json['infracciones'];
    return LicenciaPuntosMeta(
      saldoInicial: LicenciaPuntosService._saldoLegal(json['saldo_inicial']),
      saldoMaximo: LicenciaPuntosService._saldoLegal(json['saldo_maximo']),
      mesesRecuperacionTiempo: LicenciaPuntosService._int(
        json['meses_recuperacion_tiempo'],
        18,
      ),
      abilities: LicenciaPuntosAbilities.fromJson(
        LicenciaPuntosService._map(json['abilities']),
      ),
      infracciones: list is List
          ? list
                .whereType<Map>()
                .map(
                  (item) => LicenciaPuntoInfraccion.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <LicenciaPuntoInfraccion>[],
    );
  }
}

class LicenciaPuntosAbilities {
  final bool isSuperadmin;
  final bool isFomentoCulturaVial;
  final bool moduleWritesLocked;
  final bool canRestarPuntos;
  final bool canSumarPuntos;
  final bool canRecuperarPorTiempo;

  const LicenciaPuntosAbilities({
    required this.isSuperadmin,
    required this.isFomentoCulturaVial,
    required this.moduleWritesLocked,
    required this.canRestarPuntos,
    required this.canSumarPuntos,
    required this.canRecuperarPorTiempo,
  });

  factory LicenciaPuntosAbilities.fromJson(Map<String, dynamic> json) {
    return LicenciaPuntosAbilities(
      isSuperadmin: LicenciaPuntosService._bool(json['is_superadmin']),
      isFomentoCulturaVial: LicenciaPuntosService._bool(
        json['is_fomento_cultura_vial'],
      ),
      moduleWritesLocked: LicenciaPuntosService._bool(
        json['module_writes_locked'],
      ),
      canRestarPuntos: LicenciaPuntosService._bool(json['can_restar_puntos']),
      canSumarPuntos: LicenciaPuntosService._bool(json['can_sumar_puntos']),
      canRecuperarPorTiempo: LicenciaPuntosService._bool(
        json['can_recuperar_por_tiempo'],
      ),
    );
  }
}

class LicenciaPuntoInfraccion {
  final int id;
  final String codigo;
  final String nombre;
  final int puntos;
  final String descripcion;

  const LicenciaPuntoInfraccion({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.puntos,
    required this.descripcion,
  });

  factory LicenciaPuntoInfraccion.fromJson(Map<String, dynamic> json) {
    return LicenciaPuntoInfraccion(
      id: LicenciaPuntosService._int(json['id']),
      codigo: LicenciaPuntosService._string(json['codigo']),
      nombre: LicenciaPuntosService._string(json['nombre']),
      puntos: LicenciaPuntosService._int(json['puntos']),
      descripcion: LicenciaPuntosService._string(json['descripcion']),
    );
  }
}

class LicenciaPuntoCuenta {
  final int? id;
  final String numeroLicencia;
  final String tipoLicencia;
  final String titularNombre;
  final String curp;
  final String telefono;
  final int saldoActual;
  final int saldoMaximo;
  final String nivelSaldo;
  final String estado;
  final String estadoLabel;
  final String fechaRecuperacion;
  final bool cuentaRegistrada;
  final List<LicenciaPuntoMovimiento> movimientos;
  final List<LicenciaPuntoAlerta> alertas;

  const LicenciaPuntoCuenta({
    required this.id,
    required this.numeroLicencia,
    required this.tipoLicencia,
    required this.titularNombre,
    required this.curp,
    required this.telefono,
    required this.saldoActual,
    required this.saldoMaximo,
    required this.nivelSaldo,
    required this.estado,
    required this.estadoLabel,
    required this.fechaRecuperacion,
    required this.cuentaRegistrada,
    required this.movimientos,
    required this.alertas,
  });

  factory LicenciaPuntoCuenta.fromJson(Map<String, dynamic> json) {
    final movimientos = json['movimientos'];
    final alertas = json['alertas'];
    final id = LicenciaPuntosService._int(json['id']);
    return LicenciaPuntoCuenta(
      id: id > 0 ? id : null,
      numeroLicencia: LicenciaPuntosService._string(json['numero_licencia']),
      tipoLicencia: LicenciaPuntosService._string(json['tipo_licencia']),
      titularNombre: LicenciaPuntosService._string(json['titular_nombre']),
      curp: LicenciaPuntosService._string(json['curp']),
      telefono: LicenciaPuntosService._string(json['telefono']),
      saldoActual: LicenciaPuntosService._saldoActualLegal(json),
      saldoMaximo: LicenciaPuntosService._saldoLegal(json['saldo_maximo']),
      nivelSaldo: LicenciaPuntosService._string(json['nivel_saldo']),
      estado: LicenciaPuntosService._string(json['estado']),
      estadoLabel: LicenciaPuntosService._string(json['estado_label']),
      fechaRecuperacion: LicenciaPuntosService._string(
        json['fecha_recuperacion'],
      ),
      cuentaRegistrada:
          LicenciaPuntosService._bool(json['cuenta_registrada']) || id > 0,
      movimientos: movimientos is List
          ? movimientos
                .whereType<Map>()
                .map(
                  (item) => LicenciaPuntoMovimiento.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <LicenciaPuntoMovimiento>[],
      alertas: alertas is List
          ? alertas
                .whereType<Map>()
                .map(
                  (item) => LicenciaPuntoAlerta.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <LicenciaPuntoAlerta>[],
    );
  }
}

class LicenciaPuntoMovimiento {
  final String tipo;
  final int puntos;
  final int saldoAnterior;
  final int saldoNuevo;
  final String fechaMovimiento;
  final String referencia;
  final String descripcion;
  final String infraccionNombre;

  const LicenciaPuntoMovimiento({
    required this.tipo,
    required this.puntos,
    required this.saldoAnterior,
    required this.saldoNuevo,
    required this.fechaMovimiento,
    required this.referencia,
    required this.descripcion,
    required this.infraccionNombre,
  });

  factory LicenciaPuntoMovimiento.fromJson(Map<String, dynamic> json) {
    final infraccion = LicenciaPuntosService._map(json['infraccion']);
    return LicenciaPuntoMovimiento(
      tipo: LicenciaPuntosService._string(json['tipo']),
      puntos: LicenciaPuntosService._int(json['puntos']),
      saldoAnterior: LicenciaPuntosService._int(json['saldo_anterior']),
      saldoNuevo: LicenciaPuntosService._int(json['saldo_nuevo']),
      fechaMovimiento: LicenciaPuntosService._string(json['fecha_movimiento']),
      referencia: LicenciaPuntosService._string(json['referencia']),
      descripcion: LicenciaPuntosService._string(json['descripcion']),
      infraccionNombre: LicenciaPuntosService._string(infraccion['nombre']),
    );
  }
}

class LicenciaPuntoAlerta {
  final String nivel;
  final String mensaje;
  final String atendidaAt;

  const LicenciaPuntoAlerta({
    required this.nivel,
    required this.mensaje,
    required this.atendidaAt,
  });

  factory LicenciaPuntoAlerta.fromJson(Map<String, dynamic> json) {
    return LicenciaPuntoAlerta(
      nivel: LicenciaPuntosService._string(json['nivel']),
      mensaje: LicenciaPuntosService._string(json['mensaje']),
      atendidaAt: LicenciaPuntosService._string(json['atendida_at']),
    );
  }
}

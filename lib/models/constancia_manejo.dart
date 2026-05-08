class ConstanciaManejo {
  final int id;
  final String folio;
  final String qrToken;
  final String estatus;
  final String? modulo;
  final int? delegacionId;
  final String? nombreSolicitante;
  final String? sexo;
  final String? curp;
  final String? telefono;
  final String? tipoLicencia;
  final String? tipoExamen;
  final String? fechaImpresion;
  final String? fechaActivacion;
  final String? fechaExpiracion;
  final String? accesoExamenExpira;
  final String? urlExamen;
  final String? urlExamenQr;
  final String? urlExamenEscrito;
  final String? urlExamenEscritoQr;
  final String? urlImprimir;
  final String? qrExamenBase64;
  final String? qrExamenEscritoBase64;
  final String? resultado;
  final ConstanciaExamen? examen;
  final String? peritoActivador;
  final bool puedeGenerarAcceso;
  final bool puedeGenerarExamenEscrito;
  final bool puedeCapturarImpreso;
  final bool puedeImprimir;
  final bool puedeActivar;

  const ConstanciaManejo({
    required this.id,
    required this.folio,
    required this.qrToken,
    required this.estatus,
    required this.modulo,
    required this.delegacionId,
    required this.nombreSolicitante,
    required this.sexo,
    required this.curp,
    required this.telefono,
    required this.tipoLicencia,
    required this.tipoExamen,
    required this.fechaImpresion,
    required this.fechaActivacion,
    required this.fechaExpiracion,
    required this.accesoExamenExpira,
    required this.urlExamen,
    required this.urlExamenQr,
    required this.urlExamenEscrito,
    required this.urlExamenEscritoQr,
    required this.urlImprimir,
    required this.qrExamenBase64,
    required this.qrExamenEscritoBase64,
    required this.resultado,
    required this.examen,
    required this.peritoActivador,
    required this.puedeGenerarAcceso,
    required this.puedeGenerarExamenEscrito,
    required this.puedeCapturarImpreso,
    required this.puedeImprimir,
    required this.puedeActivar,
  });

  bool get tieneAccesoTemporal =>
      (urlExamen ?? '').trim().isNotEmpty &&
      (urlExamenQr ?? '').trim().isNotEmpty;

  bool get tieneExamenEscrito =>
      (urlExamenEscrito ?? '').trim().isNotEmpty &&
      (urlExamenEscritoQr ?? '').trim().isNotEmpty;

  bool get estaActiva => estatus.trim().toUpperCase() == 'ACTIVA';

  bool get estaInactiva {
    final value = estatus.trim().toUpperCase();
    return value == 'IMPRESA_INACTIVA' || value == 'PENDIENTE_EXAMEN';
  }

  bool get examenAprobado => resultado?.trim().toUpperCase() == 'APROBADO';

  factory ConstanciaManejo.fromJson(Map<String, dynamic> json) {
    return ConstanciaManejo(
      id: _readInt(json['id']) ?? 0,
      folio: (json['folio'] ?? '').toString(),
      qrToken: (json['qr_token'] ?? '').toString(),
      estatus: (json['estatus'] ?? '').toString(),
      modulo: _readNullableString(json['modulo']),
      delegacionId: _readInt(json['delegacion_id']),
      nombreSolicitante: _readNullableString(json['nombre_solicitante']),
      sexo: _readNullableString(json['sexo']),
      curp: _readNullableString(json['curp']),
      telefono: _readNullableString(json['telefono']),
      tipoLicencia: _readNullableString(json['tipo_licencia']),
      tipoExamen: _readNullableString(json['tipo_examen']),
      fechaImpresion: _readNullableString(json['fecha_impresion']),
      fechaActivacion: _readNullableString(json['fecha_activacion']),
      fechaExpiracion: _readNullableString(json['fecha_expiracion']),
      accesoExamenExpira: _readNullableString(json['acceso_examen_expira']),
      urlExamen: _readNullableString(json['url_examen']),
      urlExamenQr: _readNullableString(json['url_examen_qr']),
      urlExamenEscrito: _readNullableString(json['url_examen_escrito']),
      urlExamenEscritoQr: _readNullableString(json['url_examen_escrito_qr']),
      urlImprimir: _readNullableString(json['url_imprimir']),
      qrExamenBase64: _readNullableString(
        json['qr_examen_base64'] ??
            json['examen_qr_base64'] ??
            json['url_examen_qr_base64'],
      ),
      qrExamenEscritoBase64: _readNullableString(
        json['qr_examen_escrito_base64'] ??
            json['examen_escrito_qr_base64'] ??
            json['url_examen_escrito_qr_base64'],
      ),
      resultado: _readNullableString(json['resultado']),
      examen: json['examen'] is Map
          ? ConstanciaExamen.fromJson(
              Map<String, dynamic>.from(json['examen'] as Map),
            )
          : null,
      peritoActivador: _readNullableString(json['perito_activador']),
      puedeGenerarAcceso: _readBool(json['puede_generar_acceso']),
      puedeGenerarExamenEscrito: _readBool(
        json['puede_generar_examen_escrito'],
      ),
      puedeCapturarImpreso: _readBool(json['puede_capturar_impreso']),
      puedeImprimir: _readBool(json['puede_imprimir']),
      puedeActivar: _readBool(json['puede_activar']),
    );
  }
}

class ConstanciaModulo {
  final int id;
  final String nombre;
  final String tipo;
  final String? municipio;
  final int? delegacionId;

  const ConstanciaModulo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.municipio,
    required this.delegacionId,
  });

  String get label {
    final parts = <String>[nombre];
    if ((municipio ?? '').trim().isNotEmpty) {
      parts.add(municipio!.trim());
    }
    if (tipo.trim().isNotEmpty) {
      parts.add(tipo.replaceAll('_', ' '));
    }
    return parts.join(' - ');
  }

  factory ConstanciaModulo.fromJson(Map<String, dynamic> json) {
    return ConstanciaModulo(
      id: _readInt(json['id']) ?? 0,
      nombre: (json['nombre'] ?? '').toString(),
      tipo: (json['tipo'] ?? '').toString(),
      municipio: _readNullableString(json['municipio']),
      delegacionId: _readInt(json['delegacion_id']),
    );
  }
}

class ConstanciasManejoPage {
  final List<ConstanciaManejo> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const ConstanciasManejoPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}

class ConstanciasManejoCreateResult {
  final List<ConstanciaManejo> constancias;
  final List<int> ids;
  final String? urlImprimirLote;
  final String message;

  const ConstanciasManejoCreateResult({
    required this.constancias,
    required this.ids,
    required this.urlImprimirLote,
    required this.message,
  });
}

class ConstanciaExamenSolicitud {
  final int id;
  final String folioExamen;
  final String token;
  final int? moduloId;
  final String? modulo;
  final int? delegacionId;
  final int? constanciaId;
  final String? constanciaFolio;
  final String nombreSolicitante;
  final String sexo;
  final String? curp;
  final String? telefono;
  final String tipoLicencia;
  final String modalidad;
  final String estatus;
  final double? calificacion;
  final int? totalPreguntas;
  final int? aciertos;
  final int? errores;
  final String? fechaExamen;
  final String? tokenExpira;
  final String? observaciones;
  final String? urlExamen;
  final String? urlExamenQr;
  final String? qrExamenBase64;
  final bool puedeCapturarImpreso;
  final bool puedeActivarConstancia;

  const ConstanciaExamenSolicitud({
    required this.id,
    required this.folioExamen,
    required this.token,
    required this.moduloId,
    required this.modulo,
    required this.delegacionId,
    required this.constanciaId,
    required this.constanciaFolio,
    required this.nombreSolicitante,
    required this.sexo,
    required this.curp,
    required this.telefono,
    required this.tipoLicencia,
    required this.modalidad,
    required this.estatus,
    required this.calificacion,
    required this.totalPreguntas,
    required this.aciertos,
    required this.errores,
    required this.fechaExamen,
    required this.tokenExpira,
    required this.observaciones,
    required this.urlExamen,
    required this.urlExamenQr,
    required this.qrExamenBase64,
    required this.puedeCapturarImpreso,
    required this.puedeActivarConstancia,
  });

  bool get aprobado => estatus.trim().toUpperCase() == 'APROBADO';

  bool get esImpreso => modalidad.trim().toUpperCase() == 'IMPRESO';

  bool get tieneLiga =>
      (urlExamen ?? '').trim().isNotEmpty &&
      (urlExamenQr ?? '').trim().isNotEmpty;

  factory ConstanciaExamenSolicitud.fromJson(Map<String, dynamic> json) {
    return ConstanciaExamenSolicitud(
      id: _readInt(json['id']) ?? 0,
      folioExamen: (json['folio_examen'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      moduloId: _readInt(json['modulo_id']),
      modulo: _readNullableString(json['modulo']),
      delegacionId: _readInt(json['delegacion_id']),
      constanciaId: _readInt(json['constancia_id']),
      constanciaFolio: _readNullableString(json['constancia_folio']),
      nombreSolicitante: _readNullableString(json['nombre_solicitante']) ?? '',
      sexo: _readNullableString(json['sexo']) ?? '',
      curp: _readNullableString(json['curp']),
      telefono: _readNullableString(json['telefono']),
      tipoLicencia: _readNullableString(json['tipo_licencia']) ?? '',
      modalidad: _readNullableString(json['modalidad']) ?? '',
      estatus: _readNullableString(json['estatus']) ?? '',
      calificacion: _readDouble(json['calificacion']),
      totalPreguntas: _readInt(json['total_preguntas']),
      aciertos: _readInt(json['aciertos']),
      errores: _readInt(json['errores']),
      fechaExamen: _readNullableString(json['fecha_examen']),
      tokenExpira: _readNullableString(json['token_expira']),
      observaciones: _readNullableString(json['observaciones']),
      urlExamen: _readNullableString(json['url_examen']),
      urlExamenQr: _readNullableString(json['url_examen_qr']),
      qrExamenBase64: _readNullableString(json['qr_examen_base64']),
      puedeCapturarImpreso: _readBool(json['puede_capturar_impreso']),
      puedeActivarConstancia: _readBool(json['puede_activar_constancia']),
    );
  }
}

class ConstanciaExamen {
  final String? modalidad;
  final double? calificacion;
  final int? totalPreguntas;
  final int? aciertos;
  final int? errores;
  final String? resultado;
  final String? fechaExamen;
  final String? observaciones;

  const ConstanciaExamen({
    required this.modalidad,
    required this.calificacion,
    required this.totalPreguntas,
    required this.aciertos,
    required this.errores,
    required this.resultado,
    required this.fechaExamen,
    required this.observaciones,
  });

  factory ConstanciaExamen.fromJson(Map<String, dynamic> json) {
    return ConstanciaExamen(
      modalidad: _readNullableString(json['modalidad']),
      calificacion: _readDouble(json['calificacion']),
      totalPreguntas: _readInt(json['total_preguntas']),
      aciertos: _readInt(json['aciertos']),
      errores: _readInt(json['errores']),
      resultado: _readNullableString(json['resultado']),
      fechaExamen: _readNullableString(json['fecha_examen']),
      observaciones: _readNullableString(json['observaciones']),
    );
  }
}

String? _readNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _readDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'si' || text == 'yes';
}

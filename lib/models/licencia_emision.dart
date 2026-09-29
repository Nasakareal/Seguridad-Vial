class LicenciaEmision {
  final int id;
  final String numero;
  final String curp;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String nombres;
  final String nombreCompleto;
  final String fechaNacimiento;
  final String fechaExpedicion;
  final String fechaVencimiento;
  final String? fechaAntiguedad;
  final String tipoLicencia;
  final String genero;
  final String tipoSangre;
  final bool donadorOrganos;
  final String restricciones;
  final String oficinaEmisora;
  final String vehiculosAutorizados;
  final String estatus;
  final String? fotoUrl;
  final String? qrBase64;
  final String? emitidaPor;
  final LicenciaVinculo? constancia;
  final LicenciaVinculo? examen;

  const LicenciaEmision({
    required this.id,
    required this.numero,
    required this.curp,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.nombres,
    required this.nombreCompleto,
    required this.fechaNacimiento,
    required this.fechaExpedicion,
    required this.fechaVencimiento,
    required this.fechaAntiguedad,
    required this.tipoLicencia,
    required this.genero,
    required this.tipoSangre,
    required this.donadorOrganos,
    required this.restricciones,
    required this.oficinaEmisora,
    required this.vehiculosAutorizados,
    required this.estatus,
    required this.fotoUrl,
    required this.qrBase64,
    required this.emitidaPor,
    required this.constancia,
    required this.examen,
  });

  factory LicenciaEmision.fromJson(Map<String, dynamic> json) {
    return LicenciaEmision(
      id: _int(json['id']),
      numero: _string(json['numero']),
      curp: _string(json['curp']),
      apellidoPaterno: _string(json['apellido_paterno']),
      apellidoMaterno: _string(json['apellido_materno']),
      nombres: _string(json['nombres']),
      nombreCompleto: _string(json['nombre_completo']),
      fechaNacimiento: _string(json['fecha_nacimiento']),
      fechaExpedicion: _string(json['fecha_expedicion']),
      fechaVencimiento: _string(json['fecha_vencimiento']),
      fechaAntiguedad: _nullableString(json['fecha_antiguedad']),
      tipoLicencia: _string(json['tipo_licencia']),
      genero: _string(json['genero']),
      tipoSangre: _string(json['tipo_sangre']),
      donadorOrganos: _bool(json['donador_organos']),
      restricciones: _string(json['restricciones']),
      oficinaEmisora: _string(json['oficina_emisora']),
      vehiculosAutorizados: _string(json['vehiculos_autorizados']),
      estatus: _string(json['estatus']),
      fotoUrl: _nullableString(json['foto_url']),
      qrBase64: _nullableString(json['qr_base64']),
      emitidaPor: _nullableString(json['emitida_por']),
      constancia: _link(json['constancia']),
      examen: _link(json['examen']),
    );
  }

  static LicenciaVinculo? _link(dynamic value) {
    if (value is! Map) return null;
    return LicenciaVinculo.fromJson(Map<String, dynamic>.from(value));
  }
}

class LicenciaVinculo {
  final int id;
  final String folio;
  final String estatus;
  final double? calificacion;
  final String? fecha;

  const LicenciaVinculo({
    required this.id,
    required this.folio,
    required this.estatus,
    required this.calificacion,
    required this.fecha,
  });

  factory LicenciaVinculo.fromJson(Map<String, dynamic> json) {
    final rawScore = json['calificacion'];
    return LicenciaVinculo(
      id: _int(json['id']),
      folio: _string(json['folio']),
      estatus: _string(json['estatus']),
      calificacion: rawScore is num
          ? rawScore.toDouble()
          : double.tryParse(_string(rawScore)),
      fecha: _nullableString(json['fecha_examen'] ?? json['fecha_activacion']),
    );
  }
}

class LicenciasEmisionPage {
  final List<LicenciaEmision> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const LicenciasEmisionPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

String _string(dynamic value) => (value ?? '').toString().trim();

String? _nullableString(dynamic value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_string(value)) ?? 0;
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {'1', 'true', 'si', 'sí'}.contains(_string(value).toLowerCase());
}

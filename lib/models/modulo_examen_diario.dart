class ModuloExamenDiario {
  final int id;
  final String fecha;
  final String moduloNombre;
  final int servicioPublico;
  final int automovilista;
  final int chofer;
  final int motociclista;
  final int permiso;
  final int total;
  final int hombres;
  final int mujeres;
  final int aprobados;
  final int reprobados;
  final String? folios;
  final String? informadoPor;
  final String? createdAt;
  final String? updatedAt;

  const ModuloExamenDiario({
    required this.id,
    required this.fecha,
    required this.moduloNombre,
    required this.servicioPublico,
    required this.automovilista,
    required this.chofer,
    required this.motociclista,
    required this.permiso,
    required this.total,
    required this.hombres,
    required this.mujeres,
    required this.aprobados,
    required this.reprobados,
    required this.folios,
    required this.informadoPor,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ModuloExamenDiario.fromJson(Map<String, dynamic> json) {
    return ModuloExamenDiario(
      id: _readInt(json['id']),
      fecha: (json['fecha'] ?? '').toString(),
      moduloNombre: (json['modulo_nombre'] ?? '').toString(),
      servicioPublico: _readInt(json['servicio_publico']),
      automovilista: _readInt(json['automovilista']),
      chofer: _readInt(json['chofer']),
      motociclista: _readInt(json['motociclista']),
      permiso: _readInt(json['permiso']),
      total: _readInt(json['total']),
      hombres: _readInt(json['hombres']),
      mujeres: _readInt(json['mujeres']),
      aprobados: _readInt(json['aprobados']),
      reprobados: _readInt(json['reprobados']),
      folios: _readText(json['folios']),
      informadoPor: _readText(json['informado_por']),
      createdAt: _readText(json['created_at']),
      updatedAt: _readText(json['updated_at']),
    );
  }

  String get fechaCorta {
    try {
      final parsed = DateTime.parse(fecha);
      String two(int x) => x.toString().padLeft(2, '0');
      return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year}';
    } catch (_) {
      return fecha.isEmpty ? 'Sin fecha' : fecha;
    }
  }
}

class ModuloExamenDiarioPage {
  final List<ModuloExamenDiario> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const ModuloExamenDiarioPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

String? _readText(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

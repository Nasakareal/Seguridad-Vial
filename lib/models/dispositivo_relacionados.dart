import 'actividad.dart';

class DispositivoVehiculoRelacionado {
  final ActividadVehiculo vehiculo;
  final String rol;
  final String? observaciones;

  const DispositivoVehiculoRelacionado({
    required this.vehiculo,
    required this.rol,
    this.observaciones,
  });
}

class DispositivoPersonaRelacionada {
  final String nombre;
  final String tipoParticipacion;
  final String? curp;
  final String? telefono;
  final String? domicilio;
  final String? sexo;
  final String? ocupacion;
  final int? edad;
  final String? tipoLicencia;
  final String? estadoLicencia;
  final DateTime? vigenciaLicencia;
  final String? numeroLicencia;
  final bool permanente;
  final bool cinturon;
  final bool antecedentes;
  final bool certificadoLesiones;
  final bool certificadoAlcoholemia;
  final bool alientoEtilico;
  final String? observaciones;

  const DispositivoPersonaRelacionada({
    required this.nombre,
    required this.tipoParticipacion,
    this.curp,
    this.telefono,
    this.domicilio,
    this.sexo,
    this.ocupacion,
    this.edad,
    this.tipoLicencia,
    this.estadoLicencia,
    this.vigenciaLicencia,
    this.numeroLicencia,
    required this.permanente,
    required this.cinturon,
    required this.antecedentes,
    required this.certificadoLesiones,
    required this.certificadoAlcoholemia,
    required this.alientoEtilico,
    this.observaciones,
  });
}

import 'package:flutter/material.dart';

class HechoFormData {
  String? clientUuid;
  bool hasFotoSituacionActual = false;

  String folioC5i = '';
  String perito = '';
  String autorizacionPractico = '';
  String unidad = '';
  String unidadOrgId = '';

  TimeOfDay? hora;
  DateTime? fecha;
  String? sector;

  String calle = '';
  String colonia = '';
  String entreCalles = '';
  String municipio = '';

  String? tipoHecho;
  String? superficieVia;
  String? tiempo;
  String? clima;
  String? condiciones;
  String? controlTransito;

  bool checaronAntecedentes = false;

  String? causa;
  String responsable = '';
  String? colisionCamino;
  String? situacion;

  String vehiculosMp = '0';
  String personasMp = '0';

  String vehiculosEsperados = '0';
  String conductoresEsperados = '0';
  String lesionadosEsperados = '0';

  bool danosPatrimoniales = false;
  String propiedadesAfectadas = '';
  String montoDanos = '';

  double? lat;
  double? lng;
  String? calidadGeo;
  String? notaGeo;
  String? fuenteUbicacion;
  String? ubicacionFormateada;
  String? placeId;

  int? dictamenId;

  bool get hasClientUuid => (clientUuid?.trim().isNotEmpty ?? false);
  bool get hasCoords => lat != null && lng != null;
}

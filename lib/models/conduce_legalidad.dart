class ConduceLegalidadMeta {
  static const Set<String> fundamentosExcluidosOperativoCodigos = <String>{
    'ART420_FIV_IA_B_TRANSPORTE_PUBLICO_ESCOLAR',
    'ART465_FXI_POLARIZADO_MAYOR_20',
    'ART519_FIV_IA_NO_MOVER_SINIESTRO_DANOS',
  };
  static const List<String> fundamentosExcluidosOperativoTexto = <String>[
    'POLARIZADO',
    'TRANSPORTE PUBLICO',
    'SERVICIO PUBLICO',
    'SINIESTRO',
    'COMPETENCIAS DE VELOCIDAD',
    'PLACAS DE DEMOSTRACION',
    'SIN REGISTRO PREVIO EN REV',
    'PLACAS FORANEAS SIN REGISTRO PREVIO',
    'REGISTRO DE VISITA VENCIDO',
    'ESTACIONAR',
    'CERRAR U OBSTRUIR CIRCULACION',
    'OBSTRUIR CIRCULACION',
    'REPARACIONES A VEHICULOS',
    'REPARAR VEHICULO',
    'RESERVAR ESTACIONAMIENTO',
    'REQUERIMIENTO DE RETIRO',
    'ESPACIOS ESPECIALES DE ASCENSO',
    'ASCENSO DESCENSO TIEMPO EXCEDIDO',
  ];

  final String operativoNombre;
  final ConduceLegalidadAbilities abilities;
  final List<ConduceLegalidadFundamento> fundamentosCorralon;
  final List<ConduceLegalidadFundamento> fundamentosPersona;

  const ConduceLegalidadMeta({
    required this.operativoNombre,
    required this.abilities,
    required this.fundamentosCorralon,
    required this.fundamentosPersona,
  });

  factory ConduceLegalidadMeta.fromJson(Map<String, dynamic> json) {
    final data = _map(json['data'] ?? json);
    final fundamentos = _expandirFundamentosOperativos(
      _list(
        data['fundamentos_corralon'],
      ).map((item) => ConduceLegalidadFundamento.fromJson(_map(item))),
    ).where((item) => item.aplicaConduceLegalidadMotos).toList();
    final fundamentosPersonaPayload = _expandirFundamentosOperativos(
      _list(
        data['fundamentos_persona'],
      ).map((item) => ConduceLegalidadFundamento.fromJson(_map(item))),
    ).where((item) => item.aplicaSancionPersona).toList();

    return ConduceLegalidadMeta(
      operativoNombre:
          _str(data['operativo_nombre']) ?? 'Operativo conduce con legalidad',
      abilities: ConduceLegalidadAbilities.fromJson(_map(data['abilities'])),
      fundamentosCorralon: fundamentos,
      fundamentosPersona: fundamentosPersonaPayload.isNotEmpty
          ? fundamentosPersonaPayload
          : fundamentos.where((item) => item.aplicaSancionPersona).toList(),
    );
  }
}

class ConduceLegalidadAbilities {
  final bool canFeed;
  final bool canCreateOperativo;
  final bool canManageOperativos;
  final bool canViewAllCapturas;
  final String scope;

  const ConduceLegalidadAbilities({
    required this.canFeed,
    required this.canCreateOperativo,
    required this.canManageOperativos,
    required this.canViewAllCapturas,
    required this.scope,
  });

  const ConduceLegalidadAbilities.empty()
    : canFeed = false,
      canCreateOperativo = false,
      canManageOperativos = false,
      canViewAllCapturas = false,
      scope = 'own';

  factory ConduceLegalidadAbilities.fromJson(Map<String, dynamic> json) {
    return ConduceLegalidadAbilities(
      canFeed: _bool(json['can_feed']),
      canCreateOperativo: _bool(json['can_create_operativo']),
      canManageOperativos: _bool(json['can_manage_operativos']),
      canViewAllCapturas: _bool(json['can_view_all_capturas']),
      scope: _str(json['scope']) ?? 'own',
    );
  }
}

class ConduceLegalidadFundamento {
  final int id;
  final String? codigo;
  final String nombre;
  final String? articulo;
  final String? fraccion;
  final String? inciso;
  final String? ambitoVehiculo;
  final String? ambitoVehiculoTexto;
  final String? referenciaLegalCorta;
  final int puntos;
  final int? multaUmaMin;
  final int? multaUmaMax;
  final String? multaUmaTexto;
  final bool amonestacion;
  final bool arrestoPersona;
  final bool suspensionLicencia;
  final bool cancelacionLicencia;
  final bool depositoSiSinPersonaHabilitada;
  final bool retencionVehiculo;
  final String? sancionPersonaTexto;
  final String? resumenSanciones;
  final String? etiquetaOperativa;
  final String? textoOperativo;
  final String? descripcion;
  final String? fundamentoLegal;
  final String? narrativaSugerida;

  const ConduceLegalidadFundamento({
    required this.id,
    this.codigo,
    required this.nombre,
    this.articulo,
    this.fraccion,
    this.inciso,
    this.ambitoVehiculo,
    this.ambitoVehiculoTexto,
    this.referenciaLegalCorta,
    required this.puntos,
    this.multaUmaMin,
    this.multaUmaMax,
    this.multaUmaTexto,
    this.amonestacion = false,
    this.arrestoPersona = false,
    this.suspensionLicencia = false,
    this.cancelacionLicencia = false,
    this.depositoSiSinPersonaHabilitada = false,
    required this.retencionVehiculo,
    this.sancionPersonaTexto,
    this.resumenSanciones,
    this.etiquetaOperativa,
    this.textoOperativo,
    this.descripcion,
    this.fundamentoLegal,
    this.narrativaSugerida,
  });

  ConduceLegalidadFundamento copyWith({
    int? id,
    String? codigo,
    String? nombre,
    String? articulo,
    String? fraccion,
    String? inciso,
    String? ambitoVehiculo,
    String? ambitoVehiculoTexto,
    String? referenciaLegalCorta,
    int? puntos,
    int? multaUmaMin,
    int? multaUmaMax,
    String? multaUmaTexto,
    bool? amonestacion,
    bool? arrestoPersona,
    bool? suspensionLicencia,
    bool? cancelacionLicencia,
    bool? depositoSiSinPersonaHabilitada,
    bool? retencionVehiculo,
    String? sancionPersonaTexto,
    String? resumenSanciones,
    String? etiquetaOperativa,
    String? textoOperativo,
    String? descripcion,
    String? fundamentoLegal,
    String? narrativaSugerida,
  }) {
    return ConduceLegalidadFundamento(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      articulo: articulo ?? this.articulo,
      fraccion: fraccion ?? this.fraccion,
      inciso: inciso ?? this.inciso,
      ambitoVehiculo: ambitoVehiculo ?? this.ambitoVehiculo,
      ambitoVehiculoTexto: ambitoVehiculoTexto ?? this.ambitoVehiculoTexto,
      referenciaLegalCorta: referenciaLegalCorta ?? this.referenciaLegalCorta,
      puntos: puntos ?? this.puntos,
      multaUmaMin: multaUmaMin ?? this.multaUmaMin,
      multaUmaMax: multaUmaMax ?? this.multaUmaMax,
      multaUmaTexto: multaUmaTexto ?? this.multaUmaTexto,
      amonestacion: amonestacion ?? this.amonestacion,
      arrestoPersona: arrestoPersona ?? this.arrestoPersona,
      suspensionLicencia: suspensionLicencia ?? this.suspensionLicencia,
      cancelacionLicencia: cancelacionLicencia ?? this.cancelacionLicencia,
      depositoSiSinPersonaHabilitada:
          depositoSiSinPersonaHabilitada ?? this.depositoSiSinPersonaHabilitada,
      retencionVehiculo: retencionVehiculo ?? this.retencionVehiculo,
      sancionPersonaTexto: sancionPersonaTexto ?? this.sancionPersonaTexto,
      resumenSanciones: resumenSanciones ?? this.resumenSanciones,
      etiquetaOperativa: etiquetaOperativa ?? this.etiquetaOperativa,
      textoOperativo: textoOperativo ?? this.textoOperativo,
      descripcion: descripcion ?? this.descripcion,
      fundamentoLegal: fundamentoLegal ?? this.fundamentoLegal,
      narrativaSugerida: narrativaSugerida ?? this.narrativaSugerida,
    );
  }

  factory ConduceLegalidadFundamento.fromJson(Map<String, dynamic> json) {
    return ConduceLegalidadFundamento(
      id: _asInt(json['id']),
      codigo: _str(json['codigo']),
      nombre: _str(json['nombre']) ?? '',
      articulo: _str(json['articulo']),
      fraccion: _str(json['fraccion']),
      inciso: _str(json['inciso']),
      ambitoVehiculo: _str(json['ambito_vehiculo']),
      ambitoVehiculoTexto: _str(json['ambito_vehiculo_texto']),
      referenciaLegalCorta: _str(json['referencia_legal_corta']),
      puntos: _asInt(json['puntos']),
      multaUmaMin: _nullableInt(json['multa_uma_min']),
      multaUmaMax: _nullableInt(json['multa_uma_max']),
      multaUmaTexto: _str(json['multa_uma_texto']),
      amonestacion: _bool(json['amonestacion']),
      arrestoPersona: _bool(json['arresto_persona']),
      suspensionLicencia: _bool(json['suspension_licencia']),
      cancelacionLicencia: _bool(json['cancelacion_licencia']),
      depositoSiSinPersonaHabilitada: _bool(
        json['deposito_si_sin_persona_habilitada'],
      ),
      retencionVehiculo: _bool(json['retencion_vehiculo']),
      sancionPersonaTexto: _str(json['sancion_persona_texto']),
      resumenSanciones: _str(json['resumen_sanciones']),
      etiquetaOperativa: _str(json['etiqueta_operativa']),
      textoOperativo: _str(json['texto_operativo']),
      descripcion: _str(json['descripcion']),
      fundamentoLegal: _str(json['fundamento_legal']),
      narrativaSugerida: _str(json['narrativa_sugerida']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'codigo': codigo,
    'nombre': nombre,
    'articulo': articulo,
    'fraccion': fraccion,
    'inciso': inciso,
    'ambito_vehiculo': ambitoVehiculo,
    'ambito_vehiculo_texto': ambitoVehiculoTexto,
    'referencia_legal_corta': referenciaLegalCorta,
    'puntos': puntos,
    'multa_uma_min': multaUmaMin,
    'multa_uma_max': multaUmaMax,
    'multa_uma_texto': multaUmaTexto,
    'amonestacion': amonestacion,
    'arresto_persona': arrestoPersona,
    'suspension_licencia': suspensionLicencia,
    'cancelacion_licencia': cancelacionLicencia,
    'deposito_si_sin_persona_habilitada': depositoSiSinPersonaHabilitada,
    'retencion_vehiculo': retencionVehiculo,
    'sancion_persona_texto': sancionPersonaTexto,
    'resumen_sanciones': resumenSanciones,
    'etiqueta_operativa': etiquetaOperativa,
    'texto_operativo': textoOperativo,
    'descripcion': descripcion,
    'fundamento_legal': fundamentoLegal,
    'narrativa_sugerida': narrativaSugerida,
  }..removeWhere((_, value) => value == null);

  String get display {
    final text = (textoOperativo ?? '').trim();
    if (text.isNotEmpty) return text;
    final nombreText = nombre.trim();
    if (nombreText.isNotEmpty) return nombreText;
    final descripcionText = (descripcion ?? '').trim();
    if (descripcionText.isNotEmpty) return descripcionText;
    final etiquetaText = (etiquetaOperativa ?? '').trim();
    if (etiquetaText.isNotEmpty) return etiquetaText;
    final codigoText = (codigo ?? '').trim();
    if (codigoText.isNotEmpty) return codigoText;
    return 'Fundamento #$id';
  }

  bool get aplicaConduceLegalidadMotos {
    if (!retencionVehiculo) return false;

    final codigoText = (codigo ?? '').trim().toUpperCase();
    if (ConduceLegalidadMeta.fundamentosExcluidosOperativoCodigos.contains(
      codigoText,
    )) {
      return false;
    }

    final text = _normalizeFilterText(
      [
        codigo,
        nombre,
        etiquetaOperativa,
        textoOperativo,
        descripcion,
        fundamentoLegal,
      ].whereType<String>().join(' '),
    );

    for (final excluded
        in ConduceLegalidadMeta.fundamentosExcluidosOperativoTexto) {
      if (text.contains(excluded)) return false;
    }

    return true;
  }

  bool aplicaParaTipoGeneral(String? tipoGeneral) {
    final tipo = (tipoGeneral ?? '').trim();
    final ambito = (ambitoVehiculo ?? '').trim();
    if (tipo.isEmpty || ambito.isEmpty || ambito == 'general') return true;

    if (tipo == 'motocicleta') return ambito == 'motocicleta';
    if (tipo == 'bicicleta' || tipo == 'no_motorizado') {
      return ambito == 'no_motorizado';
    }
    if (tipo == 'camion' || tipo == 'remolque') {
      return ambito == 'carga' || ambito == 'sustancias_peligrosas';
    }

    return ambito == 'automovil';
  }

  String get sancionResumen {
    final resumen = (resumenSanciones ?? '').trim();
    if (resumen.isNotEmpty) return resumen;

    final partes = <String>[
      if (amonestacion) 'amonestacion',
      if (arrestoPersona) 'arresto',
      if (suspensionLicencia) 'suspension',
      if (cancelacionLicencia) 'cancelacion',
      if (puntos > 0) '$puntos puntos',
      if (retencionVehiculo) 'deposito',
      if (!retencionVehiculo && depositoSiSinPersonaHabilitada)
        'deposito condicional',
    ];

    return partes.isEmpty ? 'sin sancion registrada' : partes.join(' + ');
  }

  bool get aplicaSancionPersona {
    return amonestacion ||
        arrestoPersona ||
        suspensionLicencia ||
        cancelacionLicencia ||
        puntos > 0;
  }

  static String _normalizeFilterText(String value) {
    var text = value.toUpperCase().trim();
    text = text
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');
    text = text.replaceAll(RegExp(r'[^A-Z0-9]+'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }
}

class ConduceLegalidadOperativo {
  final int id;
  final String? clientUuid;
  final String nombre;
  final String? fecha;
  final String? horaInicio;
  final String? horaCierre;
  final String? municipio;
  final String? lugar;
  final String? colonia;
  final double? lat;
  final double? lng;
  final String? coordenadasTexto;
  final String? objetivo;
  final String? narrativa;
  final String? observaciones;
  final String estado;
  final bool canEdit;
  final bool canDelete;
  final int totalCapturas;
  final int misCapturas;
  final ConduceLegalidadUserRef? creador;
  final List<ConduceLegalidadCaptura> capturas;

  const ConduceLegalidadOperativo({
    required this.id,
    this.clientUuid,
    required this.nombre,
    this.fecha,
    this.horaInicio,
    this.horaCierre,
    this.municipio,
    this.lugar,
    this.colonia,
    this.lat,
    this.lng,
    this.coordenadasTexto,
    this.objetivo,
    this.narrativa,
    this.observaciones,
    required this.estado,
    this.canEdit = false,
    this.canDelete = false,
    required this.totalCapturas,
    required this.misCapturas,
    this.creador,
    this.capturas = const <ConduceLegalidadCaptura>[],
  });

  factory ConduceLegalidadOperativo.fromJson(Map<String, dynamic> json) {
    return ConduceLegalidadOperativo(
      id: _asInt(json['id']),
      clientUuid: _str(json['client_uuid']),
      nombre: _str(json['nombre']) ?? 'Operativo conduce con legalidad',
      fecha: _str(json['fecha']),
      horaInicio: _str(json['hora_inicio']),
      horaCierre: _str(json['hora_cierre']),
      municipio: _str(json['municipio']),
      lugar: _str(json['lugar']),
      colonia: _str(json['colonia']),
      lat: _double(json['lat']),
      lng: _double(json['lng']),
      coordenadasTexto: _str(json['coordenadas_texto']),
      objetivo: _str(json['objetivo']),
      narrativa: _str(json['narrativa']),
      observaciones: _str(json['observaciones']),
      estado: _str(json['estado']) ?? 'activo',
      canEdit: _bool(json['can_edit']),
      canDelete: _bool(json['can_delete']),
      totalCapturas: _asInt(json['total_capturas']),
      misCapturas: _asInt(json['mis_capturas']),
      creador: ConduceLegalidadUserRef.tryParse(json['creador']),
      capturas: _list(
        json['capturas'],
      ).map((item) => ConduceLegalidadCaptura.fromJson(_map(item))).toList(),
    );
  }
}

class ConduceLegalidadCaptura {
  final int id;
  final String? clientUuid;
  final int operativoId;
  final int? createdBy;
  final ConduceLegalidadUserRef? creador;
  final ConduceLegalidadRef? unidad;
  final ConduceLegalidadRef? delegacion;
  final String? fecha;
  final String? hora;
  final String? municipio;
  final String? lugar;
  final double? lat;
  final double? lng;
  final String? coordenadasTexto;
  final String? narrativa;
  final String? observaciones;
  final bool canEdit;
  final bool canDelete;
  final List<ConduceLegalidadVehiculo> vehiculos;
  final List<ConduceLegalidadPersona> personas;
  final List<ConduceLegalidadFoto> fotos;

  const ConduceLegalidadCaptura({
    required this.id,
    this.clientUuid,
    required this.operativoId,
    this.createdBy,
    this.creador,
    this.unidad,
    this.delegacion,
    this.fecha,
    this.hora,
    this.municipio,
    this.lugar,
    this.lat,
    this.lng,
    this.coordenadasTexto,
    this.narrativa,
    this.observaciones,
    required this.canEdit,
    this.canDelete = false,
    required this.vehiculos,
    required this.personas,
    this.fotos = const <ConduceLegalidadFoto>[],
  });

  factory ConduceLegalidadCaptura.fromJson(Map<String, dynamic> json) {
    return ConduceLegalidadCaptura(
      id: _asInt(json['id']),
      clientUuid: _str(json['client_uuid']),
      operativoId: _asInt(json['operativo_id']),
      createdBy: _nullableInt(json['created_by']),
      creador: ConduceLegalidadUserRef.tryParse(json['creador']),
      unidad: ConduceLegalidadRef.tryParse(json['unidad']),
      delegacion: ConduceLegalidadRef.tryParse(json['delegacion']),
      fecha: _str(json['fecha']),
      hora: _str(json['hora']),
      municipio: _str(json['municipio']),
      lugar: _str(json['lugar']),
      lat: _double(json['lat']),
      lng: _double(json['lng']),
      coordenadasTexto: _str(json['coordenadas_texto']),
      narrativa: _str(json['narrativa']),
      observaciones: _str(json['observaciones']),
      canEdit: _bool(json['can_edit']),
      canDelete: _bool(json['can_delete']),
      vehiculos: _list(
        json['vehiculos'],
      ).map((item) => ConduceLegalidadVehiculo.fromJson(_map(item))).toList(),
      personas: _list(
        json['personas'],
      ).map((item) => ConduceLegalidadPersona.fromJson(_map(item))).toList(),
      fotos: _list(
        json['fotos'],
      ).map((item) => ConduceLegalidadFoto.fromJson(_map(item))).toList(),
    );
  }
}

class ConduceLegalidadFoto {
  final int id;
  final String? fotoPath;
  final String? fotoThumbnailPath;
  final String? fotoUrl;
  final String? fotoThumbnailUrl;
  final String? fotoPreviewUrl;
  final int orden;

  const ConduceLegalidadFoto({
    required this.id,
    this.fotoPath,
    this.fotoThumbnailPath,
    this.fotoUrl,
    this.fotoThumbnailUrl,
    this.fotoPreviewUrl,
    this.orden = 0,
  });

  factory ConduceLegalidadFoto.fromJson(Map<String, dynamic> json) {
    return ConduceLegalidadFoto(
      id: _asInt(json['id']),
      fotoPath: _str(json['foto_path']),
      fotoThumbnailPath: _str(json['foto_thumbnail_path']),
      fotoUrl: _str(json['foto_url']),
      fotoThumbnailUrl: _str(json['foto_thumbnail_url']),
      fotoPreviewUrl: _str(json['foto_preview_url']),
      orden: _asInt(json['orden']),
    );
  }

  String? get previewUrl => fotoPreviewUrl ?? fotoThumbnailUrl ?? fotoUrl;
}

class ConduceLegalidadVehiculo {
  final int? id;
  final String? marca;
  final String? modelo;
  final String? tipoGeneral;
  final String? tipo;
  final String? linea;
  final String? color;
  final String? placas;
  final String? estadoPlacas;
  final String? serie;
  final int capacidadPersonas;
  final String? tipoServicio;
  final String? tarjetaCirculacionNombre;
  final int? gruaId;
  final int? corralonId;
  final String? grua;
  final String? corralon;
  final int? servicioUnidadId;
  final int? servicioDelegacionId;
  final int? servicioCreatedBy;
  final String? aseguradora;
  final double? montoDanos;
  final String? partesDanadas;
  final bool antecedenteVehiculo;
  final String? rawTarjetaQr;
  final int? licenciaPuntoInfraccionId;
  final String? infraccionCodigo;
  final String? fundamentoLegal;
  final bool retencionVehiculo;
  final String? motivoRetencion;
  final String? observaciones;
  final ConduceLegalidadFundamento? infraccion;

  const ConduceLegalidadVehiculo({
    this.id,
    this.marca,
    this.modelo,
    this.tipoGeneral,
    this.tipo,
    this.linea,
    this.color,
    this.placas,
    this.estadoPlacas,
    this.serie,
    this.capacidadPersonas = 0,
    this.tipoServicio,
    this.tarjetaCirculacionNombre,
    this.gruaId,
    this.corralonId,
    this.grua,
    this.corralon,
    this.servicioUnidadId,
    this.servicioDelegacionId,
    this.servicioCreatedBy,
    this.aseguradora,
    this.montoDanos,
    this.partesDanadas,
    this.antecedenteVehiculo = false,
    this.rawTarjetaQr,
    this.licenciaPuntoInfraccionId,
    this.infraccionCodigo,
    this.fundamentoLegal,
    this.retencionVehiculo = false,
    this.motivoRetencion,
    this.observaciones,
    this.infraccion,
  });

  factory ConduceLegalidadVehiculo.fromJson(Map<String, dynamic> json) {
    final motivoRetencion = _str(json['motivo_retencion']);
    final infraccion = json['infraccion'] is Map
        ? ConduceLegalidadFundamento.fromJson(_map(json['infraccion']))
        : null;

    return ConduceLegalidadVehiculo(
      id: _nullableInt(json['id']),
      marca: _str(json['marca']),
      modelo: _str(json['modelo']),
      tipoGeneral: _str(json['tipo_general']),
      tipo: _str(json['tipo']),
      linea: _str(json['linea']),
      color: _str(json['color']),
      placas: _str(json['placas']),
      estadoPlacas: _str(json['estado_placas']),
      serie: _str(json['serie']),
      capacidadPersonas: _asInt(json['capacidad_personas']),
      tipoServicio: _str(json['tipo_servicio']),
      tarjetaCirculacionNombre: _str(json['tarjeta_circulacion_nombre']),
      gruaId: _nullableInt(json['grua_id']),
      corralonId: _nullableInt(json['corralon_id']),
      grua: _str(json['grua']),
      corralon: _str(json['corralon']),
      servicioUnidadId: _nullableInt(json['servicio_unidad_id']),
      servicioDelegacionId: _nullableInt(json['servicio_delegacion_id']),
      servicioCreatedBy: _nullableInt(json['servicio_created_by']),
      aseguradora: _str(json['aseguradora']),
      montoDanos: _double(json['monto_danos']),
      partesDanadas: _str(json['partes_danadas']),
      antecedenteVehiculo: _bool(json['antecedente_vehiculo']),
      rawTarjetaQr: _str(json['raw_tarjeta_qr']),
      licenciaPuntoInfraccionId: _nullableInt(
        json['licencia_punto_infraccion_id'],
      ),
      infraccionCodigo: _str(json['infraccion_codigo']),
      fundamentoLegal: _str(json['fundamento_legal']),
      retencionVehiculo: _bool(json['retencion_vehiculo']),
      motivoRetencion: motivoRetencion,
      observaciones: _str(json['observaciones']),
      infraccion: _fundamentoPorMotivoGuardado(infraccion, motivoRetencion),
    );
  }

  Map<String, dynamic> toJson() => {
    'marca': marca,
    'modelo': modelo,
    'tipo_general': tipoGeneral,
    'tipo': tipo,
    'linea': linea,
    'color': color,
    'placas': placas,
    'estado_placas': estadoPlacas,
    'serie': serie,
    'capacidad_personas': capacidadPersonas,
    'tipo_servicio': tipoServicio,
    'tarjeta_circulacion_nombre': tarjetaCirculacionNombre,
    'grua_id': gruaId,
    'corralon_id': corralonId,
    'grua': grua,
    'corralon': corralon,
    'aseguradora': aseguradora,
    'monto_danos': montoDanos,
    'partes_danadas': partesDanadas,
    'antecedente_vehiculo': antecedenteVehiculo,
    'raw_tarjeta_qr': rawTarjetaQr,
    'licencia_punto_infraccion_id': licenciaPuntoInfraccionId,
    'motivo_retencion': motivoRetencion,
    'observaciones': observaciones,
  }..removeWhere((_, value) => value == null);
}

class ConduceLegalidadPersona {
  final int? id;
  final String? nombre;
  final String? telefono;
  final String? domicilio;
  final String? sexo;
  final String? nacionalidad;
  final String? ocupacion;
  final int? edad;
  final String? tipoLicencia;
  final String? estadoLicencia;
  final String? numeroLicencia;
  final String? vigenciaLicencia;
  final bool permanente;
  final String? rawLicenciaQr;
  final int? licenciaPuntoInfraccionId;
  final String? infraccionCodigo;
  final String? fundamentoLegal;
  final ConduceLegalidadFundamento? infraccion;
  final String? edadAproximada;
  final String? complexion;
  final String? estatura;
  final String? tez;
  final String? cabello;
  final String? prendaSuperior;
  final String? colorSuperior;
  final String? prendaInferior;
  final String? colorInferior;
  final String? calzado;
  final String? colorCalzado;
  final List<String> rasgosVisibles;
  final String? observaciones;

  const ConduceLegalidadPersona({
    this.id,
    this.nombre,
    this.telefono,
    this.domicilio,
    this.sexo,
    this.nacionalidad,
    this.ocupacion,
    this.edad,
    this.tipoLicencia,
    this.estadoLicencia,
    this.numeroLicencia,
    this.vigenciaLicencia,
    this.permanente = false,
    this.rawLicenciaQr,
    this.licenciaPuntoInfraccionId,
    this.infraccionCodigo,
    this.fundamentoLegal,
    this.infraccion,
    this.edadAproximada,
    this.complexion,
    this.estatura,
    this.tez,
    this.cabello,
    this.prendaSuperior,
    this.colorSuperior,
    this.prendaInferior,
    this.colorInferior,
    this.calzado,
    this.colorCalzado,
    this.rasgosVisibles = const <String>[],
    this.observaciones,
  });

  factory ConduceLegalidadPersona.fromJson(Map<String, dynamic> json) {
    return ConduceLegalidadPersona(
      id: _nullableInt(json['id']),
      nombre: _str(json['nombre']),
      telefono: _str(json['telefono']),
      domicilio: _str(json['domicilio']),
      sexo: _str(json['sexo']),
      nacionalidad: _str(json['nacionalidad']),
      ocupacion: _str(json['ocupacion']),
      edad: _nullableInt(json['edad']),
      tipoLicencia: _str(json['tipo_licencia']),
      estadoLicencia: _str(json['estado_licencia']),
      numeroLicencia: _str(json['numero_licencia']),
      vigenciaLicencia: _str(json['vigencia_licencia']),
      permanente: _bool(json['permanente']),
      rawLicenciaQr: _str(json['raw_licencia_qr']),
      licenciaPuntoInfraccionId: _nullableInt(
        json['licencia_punto_infraccion_id'],
      ),
      infraccionCodigo: _str(json['infraccion_codigo']),
      fundamentoLegal: _str(json['fundamento_legal']),
      infraccion: json['infraccion'] is Map
          ? ConduceLegalidadFundamento.fromJson(_map(json['infraccion']))
          : null,
      edadAproximada: _str(json['edad_aproximada']),
      complexion: _str(json['complexion']),
      estatura: _str(json['estatura']),
      tez: _str(json['tez']),
      cabello: _str(json['cabello']),
      prendaSuperior: _str(json['prenda_superior']),
      colorSuperior: _str(json['color_superior']),
      prendaInferior: _str(json['prenda_inferior']),
      colorInferior: _str(json['color_inferior']),
      calzado: _str(json['calzado']),
      colorCalzado: _str(json['color_calzado']),
      rasgosVisibles: _list(json['rasgos_visibles'])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      observaciones: _str(json['observaciones']),
    );
  }

  bool get hasDescripcionFisica =>
      edadAproximada != null ||
      complexion != null ||
      estatura != null ||
      tez != null ||
      cabello != null ||
      prendaSuperior != null ||
      colorSuperior != null ||
      prendaInferior != null ||
      colorInferior != null ||
      calzado != null ||
      colorCalzado != null ||
      rasgosVisibles.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'telefono': telefono,
    'domicilio': domicilio,
    'sexo': sexo,
    'nacionalidad': nacionalidad,
    'ocupacion': ocupacion,
    'edad': edad,
    'tipo_licencia': tipoLicencia,
    'estado_licencia': estadoLicencia,
    'numero_licencia': numeroLicencia,
    'vigencia_licencia': permanente ? null : vigenciaLicencia,
    'permanente': permanente,
    'raw_licencia_qr': rawLicenciaQr,
    'licencia_punto_infraccion_id': licenciaPuntoInfraccionId,
    'edad_aproximada': edadAproximada,
    'complexion': complexion,
    'estatura': estatura,
    'tez': tez,
    'cabello': cabello,
    'prenda_superior': prendaSuperior,
    'color_superior': colorSuperior,
    'prenda_inferior': prendaInferior,
    'color_inferior': colorInferior,
    'calzado': calzado,
    'color_calzado': colorCalzado,
    'rasgos_visibles': rasgosVisibles.isEmpty ? null : rasgosVisibles,
    'observaciones': observaciones,
  }..removeWhere((_, value) => value == null);
}

class ConduceLegalidadUserRef {
  final int id;
  final String nombre;
  final String? email;
  final String? placa;
  final String? adscripcion;
  final int? unidadId;
  final int? delegacionId;

  const ConduceLegalidadUserRef({
    required this.id,
    required this.nombre,
    this.email,
    this.placa,
    this.adscripcion,
    this.unidadId,
    this.delegacionId,
  });

  static ConduceLegalidadUserRef? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final json = _map(raw);
    final id = _asInt(json['id']);
    if (id <= 0) return null;
    return ConduceLegalidadUserRef(
      id: id,
      nombre: _str(json['name'] ?? json['nombre']) ?? 'Usuario #$id',
      email: _str(json['email']),
      placa: _str(
        json['placa'] ??
            json['numero_placa'] ??
            json['placa_agente'] ??
            json['numero_placa_agente'],
      ),
      adscripcion: _str(
        json['adscripcion'] ?? json['adscripción'] ?? json['unidad_nombre'],
      ),
      unidadId: _nullableInt(json['unidad_id']),
      delegacionId: _nullableInt(json['delegacion_id']),
    );
  }
}

class ConduceLegalidadRef {
  final int id;
  final String nombre;

  const ConduceLegalidadRef({required this.id, required this.nombre});

  static ConduceLegalidadRef? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final json = _map(raw);
    final id = _asInt(json['id']);
    if (id <= 0) return null;
    return ConduceLegalidadRef(
      id: id,
      nombre: _str(json['nombre'] ?? json['name']) ?? '#$id',
    );
  }
}

Map<String, dynamic> _map(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic raw) {
  if (raw is List) return raw;
  return const <dynamic>[];
}

String? _str(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse((value ?? '').toString().trim()) ?? 0;
}

int? _nullableInt(dynamic value) {
  final parsed = _asInt(value);
  return parsed > 0 ? parsed : null;
}

double? _double(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse((value ?? '').toString().trim());
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  final text = (value ?? '').toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'si';
}

List<ConduceLegalidadFundamento> _expandirFundamentosOperativos(
  Iterable<ConduceLegalidadFundamento> fundamentos,
) {
  final result = <ConduceLegalidadFundamento>[];
  final seen = <String>{};

  for (final fundamento in fundamentos) {
    for (final item in _variantesFundamentoOperativo(fundamento)) {
      final key = ConduceLegalidadFundamento._normalizeFilterText(
        [
          item.id.toString(),
          item.codigo,
          item.display,
          item.referenciaLegalCorta,
        ].whereType<String>().join(' '),
      );
      if (seen.add(key)) {
        result.add(item);
      }
    }
  }

  return result;
}

ConduceLegalidadFundamento? _fundamentoPorMotivoGuardado(
  ConduceLegalidadFundamento? fundamento,
  String? motivoRetencion,
) {
  if (fundamento == null) return null;

  final variantes = _variantesFundamentoOperativo(fundamento);
  if (variantes.length <= 1) return fundamento;

  final motivo = ConduceLegalidadFundamento._normalizeFilterText(
    motivoRetencion ?? '',
  );
  if (motivo.isEmpty) return fundamento;

  for (final variante in variantes) {
    final display = ConduceLegalidadFundamento._normalizeFilterText(
      variante.display,
    );
    final etiqueta = ConduceLegalidadFundamento._normalizeFilterText(
      variante.etiquetaOperativa ?? '',
    );
    if ((display.isNotEmpty && motivo.contains(display)) ||
        (etiqueta.isNotEmpty && motivo.contains(etiqueta))) {
      return variante;
    }
  }

  return fundamento;
}

List<ConduceLegalidadFundamento> _variantesFundamentoOperativo(
  ConduceLegalidadFundamento fundamento,
) {
  final text = ConduceLegalidadFundamento._normalizeFilterText(
    [
      fundamento.codigo,
      fundamento.nombre,
      fundamento.etiquetaOperativa,
      fundamento.textoOperativo,
      fundamento.descripcion,
      fundamento.fundamentoLegal,
    ].whereType<String>().join(' '),
  );

  final esMotocicleta = text.contains('MOTO') || text.contains('MOTOCIC');
  final contieneCasco = text.contains('CASCO') || text.contains('PROTECTOR');
  final contieneMenor = text.contains('MENOR');
  final contieneExcesoPersonas =
      text.contains('EXCESO') &&
      (text.contains('PERSONA') || text.contains('PASAJER'));
  final contieneLuces = text.contains('LUCES') || text.contains('LUZ');

  if (esMotocicleta && contieneCasco && contieneMenor) {
    return <ConduceLegalidadFundamento>[
      _varianteFundamento(
        fundamento,
        codigoSuffix: 'CASCO',
        nombre: 'Motocicleta sin casco protector',
        etiqueta: 'Sin casco protector',
        descripcion: 'Conducir o viajar en motocicleta sin casco protector.',
        narrativa: 'Se detecta motocicleta circulando sin casco protector.',
      ),
      _varianteFundamento(
        fundamento,
        codigoSuffix: 'MENOR',
        nombre: 'Motocicleta con pasajero menor de edad',
        etiqueta: 'Pasajero menor de edad',
        descripcion: 'Transportar pasajero menor de edad en motocicleta.',
        narrativa:
            'Se detecta motocicleta circulando con pasajero menor de edad.',
      ),
    ];
  }

  if (esMotocicleta && contieneCasco && contieneExcesoPersonas) {
    return <ConduceLegalidadFundamento>[
      _varianteFundamento(
        fundamento,
        codigoSuffix: 'EXCESO_PERSONAS',
        nombre: 'Motocicleta con exceso de personas',
        etiqueta: 'Exceso de personas',
        descripcion:
            'Llevar a bordo mas personas que las senaladas en la tarjeta de circulacion.',
        narrativa:
            'Se detecta motocicleta circulando con exceso de personas conforme a la tarjeta de circulacion.',
      ),
      _varianteFundamento(
        fundamento,
        codigoSuffix: 'CASCO',
        nombre: 'Motocicleta sin casco protector',
        etiqueta: 'Sin casco protector',
        descripcion: 'Conducir o viajar en motocicleta sin casco protector.',
        narrativa: 'Se detecta motocicleta circulando sin casco protector.',
      ),
    ];
  }

  if (esMotocicleta && contieneCasco && contieneLuces) {
    return <ConduceLegalidadFundamento>[
      _varianteFundamento(
        fundamento,
        codigoSuffix: 'LUCES',
        nombre: 'Motocicleta sin luces encendidas',
        etiqueta: 'Sin luces encendidas',
        descripcion:
            'Circular en motocicleta sin luces delanteras y traseras encendidas.',
        narrativa:
            'Se detecta motocicleta circulando sin luces delanteras y traseras encendidas.',
      ),
      _varianteFundamento(
        fundamento,
        codigoSuffix: 'REFLEJANTES',
        nombre: 'Motocicleta sin aditamentos luminosos o bandas reflejantes',
        etiqueta: 'Sin reflejantes',
        descripcion:
            'Circular en motocicleta sin aditamentos luminosos o bandas reflejantes en horario nocturno.',
        narrativa:
            'Se detecta motocicleta circulando sin aditamentos luminosos o bandas reflejantes en horario nocturno.',
      ),
    ];
  }

  return <ConduceLegalidadFundamento>[fundamento];
}

ConduceLegalidadFundamento _varianteFundamento(
  ConduceLegalidadFundamento source, {
  required String codigoSuffix,
  required String nombre,
  required String etiqueta,
  required String descripcion,
  required String narrativa,
}) {
  final codigoBase = (source.codigo ?? 'FUND_${source.id}').trim();

  return source.copyWith(
    codigo: '${codigoBase}_$codigoSuffix',
    nombre: nombre,
    etiquetaOperativa: etiqueta,
    textoOperativo: nombre,
    descripcion: descripcion,
    fundamentoLegal: _fundamentoLegalVariante(source, nombre),
    narrativaSugerida: narrativa,
  );
}

String _fundamentoLegalVariante(
  ConduceLegalidadFundamento source,
  String nombre,
) {
  final referencia = (source.referenciaLegalCorta ?? '').trim();
  if (referencia.isNotEmpty) return '$referencia - $nombre';

  final articulo = (source.articulo ?? '').trim();
  if (articulo.isNotEmpty) {
    final partes = <String>['Art. $articulo'];
    final fraccion = (source.fraccion ?? '').trim();
    final inciso = (source.inciso ?? '').trim();
    if (fraccion.isNotEmpty) partes.add('fr. $fraccion');
    if (inciso.isNotEmpty) partes.add('inc. $inciso');
    return '${partes.join(', ')} - $nombre';
  }

  return nombre;
}

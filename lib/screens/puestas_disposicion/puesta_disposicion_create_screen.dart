import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/puestas_disposicion_service.dart';
import '../../services/local_draft_service.dart';

class PuestaDisposicionCreateScreen extends StatefulWidget {
  const PuestaDisposicionCreateScreen({super.key});

  @override
  State<PuestaDisposicionCreateScreen> createState() =>
      _PuestaDisposicionCreateScreenState();
}

class _PuestaDisposicionCreateScreenState
    extends State<PuestaDisposicionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = PuestasDisposicionService();

  final _motivo = TextEditingController();
  final _lugar = TextEditingController();
  final _policia = TextEditingController();
  final _mp = TextEditingController();
  final _autoridad = TextEditingController();
  final _carpeta = TextEditingController();
  final _oficio = TextEditingController();
  final _narrativa = TextEditingController();
  final _observaciones = TextEditingController();

  bool _saving = false;
  bool _loadingUnidades = true;
  int? _unidadId;
  DateTime _fecha = DateTime.now();
  TimeOfDay? _hora;
  String _tipoPuesta = 'PERSONA';
  List<PuestaUnidad> _unidades = <PuestaUnidad>[];
  int? _hechoId;
  String? _hechoClientUuid;
  bool _routeArgsApplied = false;

  File? _pdf;
  String? _pdfName;

  final _personas = <_PersonaFields>[];
  final _vehiculos = <_VehiculoFields>[];
  final _objetos = <_ObjetoFields>[];
  late final LocalDraftAutosave _draft;

  @override
  void initState() {
    super.initState();
    _draft =
        LocalDraftAutosave(
          draftId: 'puestas_disposicion:create',
          collect: _draftValues,
        )..attachTextControllers({
          'motivo': _motivo,
          'lugar': _lugar,
          'policia': _policia,
          'mp': _mp,
          'autoridad': _autoridad,
          'carpeta': _carpeta,
          'oficio': _oficio,
          'narrativa': _narrativa,
          'observaciones': _observaciones,
        });
    _loadUnidades();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadingUnidades) {
      _applyRouteArgsIfNeeded();
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    for (final item in _personas) {
      item.dispose();
    }
    for (final item in _vehiculos) {
      item.dispose();
    }
    for (final item in _objetos) {
      item.dispose();
    }
    _motivo.dispose();
    _lugar.dispose();
    _policia.dispose();
    _mp.dispose();
    _autoridad.dispose();
    _carpeta.dispose();
    _oficio.dispose();
    _narrativa.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  Future<void> _loadUnidades() async {
    try {
      final unidades = await _service.unidadesParaCrear();
      if (!mounted) return;
      setState(() {
        _unidades = unidades;
        _unidadId = unidades.isNotEmpty ? unidades.first.id : null;
        _loadingUnidades = false;
      });
      await _restoreLocalDraft();
      if (!mounted) return;
      _applyRouteArgsIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUnidades = false);
    }
  }

  String _ymd(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  String _dmy(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Campo requerido' : null;
  }

  void _put(Map<String, String> fields, String key, String value) {
    final text = value.trim();
    if (text.isNotEmpty) fields[key] = text;
  }

  int _intFrom(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  void _applyRouteArgsIfNeeded() {
    if (_routeArgsApplied) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) {
      _routeArgsApplied = true;
      if (_hechoId != null || (_hechoClientUuid ?? '').isNotEmpty) {
        setState(() {
          _hechoId = null;
          _hechoClientUuid = null;
        });
      }
      return;
    }

    _routeArgsApplied = true;

    final hechoId = _intFrom(args['hecho_id'] ?? args['hechoId']);
    final hechoClientUuid = (args['hecho_client_uuid'] ?? '').toString().trim();
    final personasMp = _intFrom(args['personas_mp']);
    final vehiculosMp = _intFrom(args['vehiculos_mp']);
    final prefill = args['prefill'] is Map
        ? Map<String, dynamic>.from(args['prefill'] as Map)
        : const <String, dynamic>{};

    String text(String key) => (prefill[key] ?? '').toString().trim();

    setState(() {
      if (hechoId > 0) _hechoId = hechoId;
      if (hechoClientUuid.isNotEmpty) _hechoClientUuid = hechoClientUuid;

      final motivo = text('motivo');
      if (motivo.isNotEmpty) _motivo.text = motivo;

      final lugar = text('lugar');
      if (lugar.isNotEmpty) _lugar.text = lugar;

      final policia = text('policia');
      if (policia.isNotEmpty) _policia.text = policia;

      final oficio = text('oficio');
      if (oficio.isNotEmpty) _oficio.text = oficio;

      final fecha = DateTime.tryParse(text('fecha'));
      if (fecha != null) _fecha = fecha;

      final hora = _parseTime(text('hora'));
      if (hora != null) _hora = hora;

      if (personasMp > 0 && vehiculosMp > 0) {
        _tipoPuesta = 'MIXTA';
      } else if (vehiculosMp > 0) {
        _tipoPuesta = 'VEHICULO';
      } else if (personasMp > 0) {
        _tipoPuesta = 'PERSONA';
      }

      _ensureRequiredPersonas(personasMp);
      _ensureRequiredVehiculos(vehiculosMp);
    });
    _attachDynamicDraftControllers();
    _markDraftChanged();
  }

  void _ensureRequiredPersonas(int count) {
    if (count <= 0) return;
    while (_personas.length < count) {
      _personas.add(_PersonaFields(requiredEntry: true));
    }
    for (var i = 0; i < count && i < _personas.length; i += 1) {
      _personas[i].requiredEntry = true;
    }
  }

  void _ensureRequiredVehiculos(int count) {
    if (count <= 0) return;
    while (_vehiculos.length < count) {
      _vehiculos.add(_VehiculoFields(requiredEntry: true));
    }
    for (var i = 0; i < count && i < _vehiculos.length; i += 1) {
      _vehiculos[i].requiredEntry = true;
    }
  }

  Map<String, dynamic> _draftValues() {
    return <String, dynamic>{
      'tipo_puesta': _tipoPuesta,
      'unidad_id': _unidadId,
      'hecho_id': _hechoId,
      'hecho_client_uuid': _hechoClientUuid,
      'fecha': _ymd(_fecha),
      'hora': _hora == null
          ? null
          : '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}',
      'motivo': _motivo.text,
      'lugar': _lugar.text,
      'policia': _policia.text,
      'mp': _mp.text,
      'autoridad': _autoridad.text,
      'carpeta': _carpeta.text,
      'oficio': _oficio.text,
      'narrativa': _narrativa.text,
      'observaciones': _observaciones.text,
      'pdf_path': _pdf?.path,
      'pdf_name': _pdfName,
      'personas': _personas.map(_personaToJson).toList(),
      'vehiculos': _vehiculos.map(_vehiculoToJson).toList(),
      'objetos': _objetos.map(_objetoToJson).toList(),
    };
  }

  Future<void> _restoreLocalDraft() async {
    final restored = await _draft.restore(_applyLocalDraft);
    if (!mounted || !restored) return;
    _attachDynamicDraftControllers();
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Borrador local recuperado.')));
  }

  void _applyLocalDraft(Map<String, dynamic> draft) {
    _tipoPuesta = (draft['tipo_puesta'] ?? _tipoPuesta).toString();
    _unidadId = _intValue(draft['unidad_id']) ?? _unidadId;
    _hechoId = _intValue(draft['hecho_id']);
    _hechoClientUuid = (draft['hecho_client_uuid'] ?? '').toString().trim();
    if ((_hechoClientUuid ?? '').isEmpty) _hechoClientUuid = null;
    _fecha = DateTime.tryParse((draft['fecha'] ?? '').toString()) ?? _fecha;
    _hora = _parseTime(draft['hora']) ?? _hora;
    _motivo.text = (draft['motivo'] ?? '').toString();
    _lugar.text = (draft['lugar'] ?? '').toString();
    _policia.text = (draft['policia'] ?? '').toString();
    _mp.text = (draft['mp'] ?? '').toString();
    _autoridad.text = (draft['autoridad'] ?? '').toString();
    _carpeta.text = (draft['carpeta'] ?? '').toString();
    _oficio.text = (draft['oficio'] ?? '').toString();
    _narrativa.text = (draft['narrativa'] ?? '').toString();
    _observaciones.text = (draft['observaciones'] ?? '').toString();

    final pdfPath = (draft['pdf_path'] ?? '').toString().trim();
    if (pdfPath.isNotEmpty) {
      final file = File(pdfPath);
      if (file.existsSync()) {
        _pdf = file;
        _pdfName = (draft['pdf_name'] ?? '').toString().trim();
        if ((_pdfName ?? '').isEmpty) {
          _pdfName = pdfPath.split(Platform.pathSeparator).last;
        }
      }
    }

    _personas
      ..forEach((item) => item.dispose())
      ..clear()
      ..addAll(_personasFromDraft(draft['personas']));
    _vehiculos
      ..forEach((item) => item.dispose())
      ..clear()
      ..addAll(_vehiculosFromDraft(draft['vehiculos']));
    _objetos
      ..forEach((item) => item.dispose())
      ..clear()
      ..addAll(_objetosFromDraft(draft['objetos']));
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString().trim());
  }

  TimeOfDay? _parseTime(dynamic value) {
    final parts = (value ?? '').toString().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _boolValue(dynamic value) {
    if (value is bool) return value;
    final raw = (value ?? '').toString().trim().toLowerCase();
    return raw == '1' || raw == 'true' || raw == 'si' || raw == 'sí';
  }

  void _attachDynamicDraftControllers() {
    final controllers = <String, TextEditingController>{};
    for (var i = 0; i < _personas.length; i++) {
      final item = _personas[i];
      controllers.addAll({
        'personas.$i.nombre': item.nombre,
        'personas.$i.alias': item.alias,
        'personas.$i.edad': item.edad,
        'personas.$i.sexo': item.sexo,
        'personas.$i.fecha_nacimiento': item.fechaNacimiento,
        'personas.$i.curp': item.curp,
        'personas.$i.rfc': item.rfc,
        'personas.$i.calidad': item.calidad,
        'personas.$i.domicilio': item.domicilio,
        'personas.$i.delito': item.delito,
        'personas.$i.mandamiento': item.mandamiento,
        'personas.$i.observaciones': item.observaciones,
      });
    }
    for (var i = 0; i < _vehiculos.length; i++) {
      final item = _vehiculos[i];
      controllers.addAll({
        'vehiculos.$i.tipo': item.tipo,
        'vehiculos.$i.marca': item.marca,
        'vehiculos.$i.submarca': item.submarca,
        'vehiculos.$i.modelo': item.modelo,
        'vehiculos.$i.color': item.color,
        'vehiculos.$i.placas': item.placas,
        'vehiculos.$i.serie': item.serie,
        'vehiculos.$i.calidad': item.calidad,
        'vehiculos.$i.motivo': item.motivoRelacion,
        'vehiculos.$i.reporte_robo': item.numeroReporteRobo,
        'vehiculos.$i.observaciones': item.observaciones,
      });
    }
    for (var i = 0; i < _objetos.length; i++) {
      final item = _objetos[i];
      controllers.addAll({
        'objetos.$i.tipo': item.tipoObjeto,
        'objetos.$i.descripcion': item.descripcion,
        'objetos.$i.cantidad': item.cantidad,
        'objetos.$i.unidad': item.unidadMedida,
        'objetos.$i.cadena': item.cadenaCustodia,
        'objetos.$i.observaciones': item.observaciones,
      });
    }
    _draft.attachTextControllers(controllers);
  }

  void _addPersona() {
    setState(() => _personas.add(_PersonaFields()));
    _attachDynamicDraftControllers();
    _markDraftChanged();
  }

  void _addVehiculo() {
    setState(() => _vehiculos.add(_VehiculoFields()));
    _attachDynamicDraftControllers();
    _markDraftChanged();
  }

  void _addObjeto() {
    setState(() => _objetos.add(_ObjetoFields()));
    _attachDynamicDraftControllers();
    _markDraftChanged();
  }

  void _markDraftChanged() {
    _draft.notifyChanged();
  }

  Map<String, dynamic> _personaToJson(_PersonaFields item) {
    return <String, dynamic>{
      'nombre': item.nombre.text,
      'alias': item.alias.text,
      'edad': item.edad.text,
      'sexo': item.sexo.text,
      'fecha_nacimiento': item.fechaNacimiento.text,
      'curp': item.curp.text,
      'rfc': item.rfc.text,
      'calidad': item.calidad.text,
      'domicilio': item.domicilio.text,
      'delito': item.delito.text,
      'orden_aprehension': item.ordenAprehension,
      'mandamiento': item.mandamiento.text,
      'observaciones': item.observaciones.text,
      'required_entry': item.requiredEntry,
      'uso_fuerza_pdf_path': item.usoFuerzaPdf?.path,
      'uso_fuerza_pdf_name': item.usoFuerzaPdfName,
    };
  }

  _PersonaFields _personaFromJson(Map<String, dynamic> data) {
    return _PersonaFields()
      ..nombre.text = (data['nombre'] ?? '').toString()
      ..alias.text = (data['alias'] ?? '').toString()
      ..edad.text = (data['edad'] ?? '').toString()
      ..sexo.text = (data['sexo'] ?? '').toString()
      ..fechaNacimiento.text = (data['fecha_nacimiento'] ?? '').toString()
      ..curp.text = (data['curp'] ?? '').toString()
      ..rfc.text = (data['rfc'] ?? '').toString()
      ..calidad.text = (data['calidad'] ?? '').toString()
      ..domicilio.text = (data['domicilio'] ?? '').toString()
      ..delito.text = (data['delito'] ?? '').toString()
      ..ordenAprehension = _boolValue(data['orden_aprehension'])
      ..mandamiento.text = (data['mandamiento'] ?? '').toString()
      ..observaciones.text = (data['observaciones'] ?? '').toString()
      ..requiredEntry = _boolValue(data['required_entry'])
      ..restoreUsoFuerzaPdf(
        (data['uso_fuerza_pdf_path'] ?? '').toString(),
        (data['uso_fuerza_pdf_name'] ?? '').toString(),
      );
  }

  List<_PersonaFields> _personasFromDraft(dynamic value) {
    if (value is! List) return <_PersonaFields>[];
    return value
        .whereType<Map>()
        .map((item) => _personaFromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Map<String, dynamic> _vehiculoToJson(_VehiculoFields item) {
    return <String, dynamic>{
      'tipo': item.tipo.text,
      'marca': item.marca.text,
      'submarca': item.submarca.text,
      'modelo': item.modelo.text,
      'color': item.color.text,
      'placas': item.placas.text,
      'serie': item.serie.text,
      'calidad': item.calidad.text,
      'motivo_relacion': item.motivoRelacion.text,
      'con_reporte_robo': item.conReporteRobo,
      'numero_reporte_robo': item.numeroReporteRobo.text,
      'observaciones': item.observaciones.text,
      'required_entry': item.requiredEntry,
    };
  }

  _VehiculoFields _vehiculoFromJson(Map<String, dynamic> data) {
    return _VehiculoFields()
      ..tipo.text = (data['tipo'] ?? '').toString()
      ..marca.text = (data['marca'] ?? '').toString()
      ..submarca.text = (data['submarca'] ?? '').toString()
      ..modelo.text = (data['modelo'] ?? '').toString()
      ..color.text = (data['color'] ?? '').toString()
      ..placas.text = (data['placas'] ?? '').toString()
      ..serie.text = (data['serie'] ?? '').toString()
      ..calidad.text = (data['calidad'] ?? '').toString()
      ..motivoRelacion.text = (data['motivo_relacion'] ?? '').toString()
      ..conReporteRobo = _boolValue(data['con_reporte_robo'])
      ..numeroReporteRobo.text = (data['numero_reporte_robo'] ?? '').toString()
      ..observaciones.text = (data['observaciones'] ?? '').toString()
      ..requiredEntry = _boolValue(data['required_entry']);
  }

  List<_VehiculoFields> _vehiculosFromDraft(dynamic value) {
    if (value is! List) return <_VehiculoFields>[];
    return value
        .whereType<Map>()
        .map((item) => _vehiculoFromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Map<String, dynamic> _objetoToJson(_ObjetoFields item) {
    return <String, dynamic>{
      'tipo_objeto': item.tipoObjeto.text,
      'descripcion': item.descripcion.text,
      'cantidad': item.cantidad.text,
      'unidad_medida': item.unidadMedida.text,
      'cadena_custodia': item.cadenaCustodia.text,
      'observaciones': item.observaciones.text,
    };
  }

  _ObjetoFields _objetoFromJson(Map<String, dynamic> data) {
    return _ObjetoFields()
      ..tipoObjeto.text = (data['tipo_objeto'] ?? '').toString()
      ..descripcion.text = (data['descripcion'] ?? '').toString()
      ..cantidad.text = (data['cantidad'] ?? '').toString()
      ..unidadMedida.text = (data['unidad_medida'] ?? '').toString()
      ..cadenaCustodia.text = (data['cadena_custodia'] ?? '').toString()
      ..observaciones.text = (data['observaciones'] ?? '').toString();
  }

  List<_ObjetoFields> _objetosFromDraft(dynamic value) {
    if (value is! List) return <_ObjetoFields>[];
    return value
        .whereType<Map>()
        .map((item) => _objetoFromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1),
    );

    if (picked != null && mounted) {
      setState(() => _fecha = picked);
      _markDraftChanged();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() => _hora = picked);
      _markDraftChanged();
    }
  }

  Future<void> _pickPdf() async {
    try {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: false,
        withData: false,
      );
      if (selected == null || selected.files.isEmpty) return;

      final picked = selected.files.single;
      final path = picked.path;
      if (path == null || path.trim().isEmpty) {
        throw Exception('No se pudo leer el PDF seleccionado.');
      }

      setState(() {
        _pdf = File(path);
        _pdfName = picked.name;
      });
      _markDraftChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo seleccionar el PDF.')),
      );
    }
  }

  Future<void> _pickUsoFuerzaPdf(_PersonaFields item) async {
    try {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: false,
        withData: false,
      );
      if (selected == null || selected.files.isEmpty) return;

      final picked = selected.files.single;
      final path = picked.path;
      if (path == null || path.trim().isEmpty) {
        throw Exception('No se pudo leer el PDF seleccionado.');
      }

      final file = File(path);
      if (!await file.exists()) {
        throw Exception('No se encontró el PDF seleccionado.');
      }
      if (await file.length() > 10 * 1024 * 1024) {
        throw Exception('El PDF es muy pesado (máximo 10 MB).');
      }

      if (!mounted) return;
      setState(() {
        item.usoFuerzaPdf = file;
        item.usoFuerzaPdfName = picked.name;
      });
      _markDraftChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      if (kDebugMode) {
        debugPrint('Puesta a disposicion: formulario invalido');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos marcados.')),
      );
      return;
    }

    if (_unidadId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una unidad.')));
      return;
    }

    final personasIncluidas = _personas
        .where((item) => item.isIncluded)
        .toList(growable: false);
    for (var i = 0; i < personasIncluidas.length; i += 1) {
      final persona = personasIncluidas[i];
      if (persona.usoFuerzaPdf == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Agrega el PDF de uso de fuerza en Persona ${i + 1}.',
            ),
          ),
        );
        return;
      }
    }

    final vehiculosIncluidos = _vehiculos
        .where((item) => item.isIncluded)
        .toList(growable: false);
    final objetosIncluidos = _objetos
        .where((item) => item.hasAny)
        .toList(growable: false);

    final fields = <String, String>{
      'unidad_id': _unidadId.toString(),
      'tipo_puesta': _tipoPuesta,
      'motivo': _motivo.text.trim(),
      'estatus': 'ACTIVA',
      'nombre_policia': _policia.text.trim(),
      'fecha_puesta': _ymd(_fecha),
    };

    if ((_hechoId ?? 0) > 0) {
      fields['hecho_id'] = _hechoId.toString();
    }
    final hechoClientUuid = (_hechoClientUuid ?? '').trim();
    if (hechoClientUuid.isNotEmpty) {
      fields['hecho_client_uuid'] = hechoClientUuid;
    }

    if (_hora != null) {
      fields['hora_puesta'] =
          '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}';
    }

    _put(fields, 'lugar_puesta', _lugar.text);
    _put(fields, 'nombre_mp', _mp.text);
    _put(fields, 'autoridad_receptora', _autoridad.text);
    _put(fields, 'carpeta_investigacion', _carpeta.text);
    _put(fields, 'oficio', _oficio.text);
    _put(fields, 'narrativa', _narrativa.text);
    _put(fields, 'observaciones', _observaciones.text);

    var index = 0;
    final archivosExtra = <PuestaUploadFile>[];
    for (final item in personasIncluidas) {
      item.write(fields, index++);
      final usoFuerzaPdf = item.usoFuerzaPdf;
      if (usoFuerzaPdf != null) {
        archivosExtra.add(
          PuestaUploadFile(
            field: 'personas[${index - 1}][archivo_uso_fuerza]',
            file: usoFuerzaPdf,
          ),
        );
      }
    }

    index = 0;
    for (final item in vehiculosIncluidos) {
      item.write(fields, index++);
    }

    index = 0;
    for (final item in objetosIncluidos) {
      item.write(fields, index++);
    }

    if (kDebugMode) {
      debugPrint(
        'Puesta a disposicion: enviando unidad=$_unidadId tipo=$_tipoPuesta hecho=$_hechoId personas=${personasIncluidas.length} vehiculos=${vehiculosIncluidos.length} objetos=${objetosIncluidos.length}',
      );
    }

    setState(() => _saving = true);

    try {
      await _service.store(
        fields: fields,
        archivoPuesta: _pdf,
        archivosExtra: archivosExtra,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Puesta registrada.')));
      await _draft.discard();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo registrar: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Crear Puesta a Disposición'),
        backgroundColor: Colors.blue,
      ),
      body: _loadingUnidades
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Section(
                    title: 'Llene los Datos',
                    children: [
                      _readonly('Número de Puesta', 'Se asigna al registrar'),
                      if ((_hechoId ?? 0) > 0) ...[
                        const SizedBox(height: 12),
                        _readonly('Hecho vinculado', '#$_hechoId'),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _tipoPuesta,
                        decoration: _decoration('Tipo de Puesta'),
                        items: const [
                          DropdownMenuItem(
                            value: 'PERSONA',
                            child: Text('PERSONA'),
                          ),
                          DropdownMenuItem(
                            value: 'VEHICULO',
                            child: Text('VEHICULO'),
                          ),
                          DropdownMenuItem(
                            value: 'OBJETO',
                            child: Text('OBJETO'),
                          ),
                          DropdownMenuItem(
                            value: 'MIXTA',
                            child: Text('MIXTA'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                setState(
                                  () => _tipoPuesta = value ?? 'PERSONA',
                                );
                                _markDraftChanged();
                              },
                      ),
                      const SizedBox(height: 12),
                      _field(_motivo, 'Motivo', validator: _required),
                      const SizedBox(height: 12),
                      _readonly('Estatus', 'ACTIVA'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Fecha y lugar',
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fecha de Puesta'),
                        subtitle: Text(_dmy(_fecha)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _saving ? null : _pickDate,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Hora de Puesta'),
                        subtitle: Text(
                          _hora == null ? 'Sin hora' : _hora!.format(context),
                        ),
                        trailing: const Icon(Icons.schedule),
                        onTap: _saving ? null : _pickTime,
                      ),
                      const SizedBox(height: 12),
                      _field(_lugar, 'Lugar de Puesta'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Datos de autoridad',
                    children: [
                      _field(
                        _policia,
                        'Nombre del Policía',
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      _field(_mp, 'Nombre del MP'),
                      const SizedBox(height: 12),
                      _field(_autoridad, 'Autoridad Receptora'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Área y expediente',
                    children: [
                      DropdownButtonFormField<int>(
                        value: _unidadId,
                        decoration: _decoration('Unidad / Área'),
                        items: [
                          for (final unidad in _unidades)
                            DropdownMenuItem(
                              value: unidad.id,
                              child: Text(unidad.nombre),
                            ),
                        ],
                        validator: (value) =>
                            value == null ? 'Campo requerido' : null,
                        onChanged: _saving
                            ? null
                            : (value) {
                                setState(() => _unidadId = value);
                                _markDraftChanged();
                              },
                      ),
                      const SizedBox(height: 12),
                      _field(_carpeta, 'Carpeta de Investigación'),
                      const SizedBox(height: 12),
                      _field(_oficio, 'Oficio'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Archivo PDF',
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _pdfName ?? 'Sin archivo',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_pdf == null)
                            OutlinedButton(
                              onPressed: _saving ? null : _pickPdf,
                              child: const Text('Elegir'),
                            )
                          else
                            IconButton(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      setState(() {
                                        _pdf = null;
                                        _pdfName = null;
                                      });
                                      _markDraftChanged();
                                    },
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Narrativa',
                    children: [_field(_narrativa, 'Narrativa', maxLines: 4)],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Observaciones',
                    children: [
                      _field(_observaciones, 'Observaciones', maxLines: 3),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _dynamicSection(
                    title: 'Personas',
                    button: 'Agregar Persona',
                    onAdd: _addPersona,
                    children: [
                      for (var i = 0; i < _personas.length; i++)
                        _personaCard(_personas[i], i),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _dynamicSection(
                    title: 'Vehículos',
                    button: 'Agregar Vehículo',
                    onAdd: _addVehiculo,
                    children: [
                      for (var i = 0; i < _vehiculos.length; i++)
                        _vehiculoCard(_vehiculos[i], i),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _dynamicSection(
                    title: 'Objetos',
                    button: 'Agregar Objeto',
                    onAdd: _addObjeto,
                    children: [
                      for (var i = 0; i < _objetos.length; i++)
                        _objetoCard(_objetos[i], i),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Guardando' : 'Registrar'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  Widget _readonly(String label, String value) {
    return TextFormField(
      enabled: false,
      initialValue: value,
      decoration: _decoration(label),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    FormFieldValidator<String>? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _decoration(label),
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.characters,
    );
  }

  Widget _dynamicSection({
    required String title,
    required String button,
    required VoidCallback onAdd,
    required List<Widget> children,
  }) {
    return _Section(
      title: title,
      trailing: OutlinedButton.icon(
        onPressed: _saving ? null : onAdd,
        icon: const Icon(Icons.add),
        label: Text(button),
      ),
      children: children.isEmpty
          ? [
              Text(
                'Sin registros.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ]
          : children,
    );
  }

  Widget _personaCard(_PersonaFields item, int index) {
    return _DynamicBlock(
      title: 'Persona ${index + 1}',
      onRemove: () {
        setState(() => _personas.removeAt(index).dispose());
        _markDraftChanged();
      },
      children: [
        _field(
          item.nombre,
          'Nombre Completo',
          validator: (_) => item.isIncluded && item.nombre.text.trim().isEmpty
              ? 'Campo requerido'
              : null,
        ),
        const SizedBox(height: 10),
        _field(item.alias, 'Alias'),
        const SizedBox(height: 10),
        _field(item.edad, 'Edad', keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        _field(item.sexo, 'Sexo'),
        const SizedBox(height: 10),
        _field(item.fechaNacimiento, 'Fecha de Nacimiento (AAAA-MM-DD)'),
        const SizedBox(height: 10),
        _field(item.curp, 'CURP'),
        const SizedBox(height: 10),
        _field(item.rfc, 'RFC'),
        const SizedBox(height: 10),
        _field(item.calidad, 'Calidad'),
        const SizedBox(height: 10),
        _field(item.domicilio, 'Domicilio'),
        const SizedBox(height: 10),
        _field(item.delito, 'Delito o Motivo'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: item.ordenAprehension,
          title: const Text('Orden de Aprehensión'),
          onChanged: (value) {
            setState(() => item.ordenAprehension = value ?? false);
            _markDraftChanged();
          },
        ),
        _field(item.mandamiento, 'Mandamiento Judicial'),
        const SizedBox(height: 10),
        _field(item.observaciones, 'Observaciones'),
        const SizedBox(height: 10),
        _personaUsoFuerzaPdfField(item),
      ],
    );
  }

  Widget _personaUsoFuerzaPdfField(_PersonaFields item) {
    return InputDecorator(
      decoration: _decoration('PDF uso de fuerza *'),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.usoFuerzaPdfName ?? 'Sin archivo',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.usoFuerzaPdf == null)
            OutlinedButton(
              onPressed: _saving ? null : () => _pickUsoFuerzaPdf(item),
              child: const Text('Elegir'),
            )
          else
            IconButton(
              onPressed: _saving
                  ? null
                  : () {
                      setState(() {
                        item.usoFuerzaPdf = null;
                        item.usoFuerzaPdfName = null;
                      });
                      _markDraftChanged();
                    },
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }

  Widget _vehiculoCard(_VehiculoFields item, int index) {
    return _DynamicBlock(
      title: 'Vehículo ${index + 1}',
      onRemove: () {
        setState(() => _vehiculos.removeAt(index).dispose());
        _markDraftChanged();
      },
      children: [
        _field(
          item.tipo,
          'Tipo',
          validator: (_) =>
              item.isIncluded &&
                  item.tipo.text.trim().isEmpty &&
                  item.placas.text.trim().isEmpty
              ? 'Captura tipo o placas'
              : null,
        ),
        const SizedBox(height: 10),
        _field(item.marca, 'Marca'),
        const SizedBox(height: 10),
        _field(item.submarca, 'Línea'),
        const SizedBox(height: 10),
        _field(item.modelo, 'Modelo'),
        const SizedBox(height: 10),
        _field(item.color, 'Color'),
        const SizedBox(height: 10),
        _field(
          item.placas,
          'Placas',
          validator: (_) =>
              item.isIncluded &&
                  item.tipo.text.trim().isEmpty &&
                  item.placas.text.trim().isEmpty
              ? 'Captura tipo o placas'
              : null,
        ),
        const SizedBox(height: 10),
        _field(item.serie, 'Serie'),
        const SizedBox(height: 10),
        _field(item.calidad, 'Calidad'),
        const SizedBox(height: 10),
        _field(item.motivoRelacion, 'Motivo Relación'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: item.conReporteRobo,
          title: const Text('Con Reporte de Robo'),
          onChanged: (value) {
            setState(() => item.conReporteRobo = value ?? false);
            _markDraftChanged();
          },
        ),
        _field(item.numeroReporteRobo, 'Número Reporte Robo'),
        const SizedBox(height: 10),
        _field(item.observaciones, 'Observaciones'),
      ],
    );
  }

  Widget _objetoCard(_ObjetoFields item, int index) {
    return _DynamicBlock(
      title: 'Objeto ${index + 1}',
      onRemove: () {
        setState(() => _objetos.removeAt(index).dispose());
        _markDraftChanged();
      },
      children: [
        _field(
          item.tipoObjeto,
          'Tipo de Objeto',
          validator: (_) =>
              item.hasAny &&
                  item.tipoObjeto.text.trim().isEmpty &&
                  item.descripcion.text.trim().isEmpty
              ? 'Captura tipo o descripción'
              : null,
        ),
        const SizedBox(height: 10),
        _field(
          item.descripcion,
          'Descripción',
          validator: (_) =>
              item.hasAny &&
                  item.tipoObjeto.text.trim().isEmpty &&
                  item.descripcion.text.trim().isEmpty
              ? 'Captura tipo o descripción'
              : null,
        ),
        const SizedBox(height: 10),
        _field(item.cantidad, 'Cantidad', keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        _field(item.unidadMedida, 'Unidad Medida'),
        const SizedBox(height: 10),
        _field(item.cadenaCustodia, 'Cadena de Custodia'),
        const SizedBox(height: 10),
        _field(item.observaciones, 'Observaciones'),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _Section({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DynamicBlock extends StatelessWidget {
  final String title;
  final VoidCallback onRemove;
  final List<Widget> children;

  const _DynamicBlock({
    required this.title,
    required this.onRemove,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Quitar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _PersonaFields {
  _PersonaFields({this.requiredEntry = false});

  final nombre = TextEditingController();
  final alias = TextEditingController();
  final edad = TextEditingController();
  final sexo = TextEditingController();
  final fechaNacimiento = TextEditingController();
  final curp = TextEditingController();
  final rfc = TextEditingController();
  final calidad = TextEditingController();
  final domicilio = TextEditingController();
  final delito = TextEditingController();
  final mandamiento = TextEditingController();
  final observaciones = TextEditingController();
  File? usoFuerzaPdf;
  String? usoFuerzaPdfName;
  bool ordenAprehension = false;
  bool requiredEntry;

  bool get hasAny => [
    nombre,
    alias,
    edad,
    sexo,
    fechaNacimiento,
    curp,
    rfc,
    calidad,
    domicilio,
    delito,
    mandamiento,
    observaciones,
  ].any((controller) => controller.text.trim().isNotEmpty);

  bool get isIncluded => requiredEntry || hasAny || usoFuerzaPdf != null;

  void restoreUsoFuerzaPdf(String path, String name) {
    final cleanPath = path.trim();
    if (cleanPath.isEmpty) return;

    final file = File(cleanPath);
    if (!file.existsSync()) return;

    usoFuerzaPdf = file;
    usoFuerzaPdfName = name.trim().isEmpty
        ? cleanPath.split(Platform.pathSeparator).last
        : name.trim();
  }

  void write(Map<String, String> fields, int index) {
    void put(String key, TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) fields['personas[$index][$key]'] = text;
    }

    put('nombre_completo', nombre);
    put('alias', alias);
    put('edad', edad);
    put('sexo', sexo);
    put('fecha_nacimiento', fechaNacimiento);
    put('curp', curp);
    put('rfc', rfc);
    put('calidad', calidad);
    put('domicilio', domicilio);
    put('delito_o_motivo', delito);
    put('mandamiento_judicial', mandamiento);
    put('observaciones', observaciones);
    if (ordenAprehension) fields['personas[$index][orden_aprehension]'] = '1';
  }

  void dispose() {
    for (final controller in [
      nombre,
      alias,
      edad,
      sexo,
      fechaNacimiento,
      curp,
      rfc,
      calidad,
      domicilio,
      delito,
      mandamiento,
      observaciones,
    ]) {
      controller.dispose();
    }
  }
}

class _VehiculoFields {
  _VehiculoFields({this.requiredEntry = false});

  final tipo = TextEditingController();
  final marca = TextEditingController();
  final submarca = TextEditingController();
  final modelo = TextEditingController();
  final color = TextEditingController();
  final placas = TextEditingController();
  final serie = TextEditingController();
  final calidad = TextEditingController();
  final motivoRelacion = TextEditingController();
  final numeroReporteRobo = TextEditingController();
  final observaciones = TextEditingController();
  bool conReporteRobo = false;
  bool requiredEntry;

  bool get hasAny => [
    tipo,
    marca,
    submarca,
    modelo,
    color,
    placas,
    serie,
    calidad,
    motivoRelacion,
    numeroReporteRobo,
    observaciones,
  ].any((controller) => controller.text.trim().isNotEmpty);

  bool get isIncluded => requiredEntry || hasAny;

  void write(Map<String, String> fields, int index) {
    void put(String key, TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) fields['vehiculos[$index][$key]'] = text;
    }

    put('tipo', tipo);
    put('marca', marca);
    put('submarca', submarca);
    put('modelo', modelo);
    put('color', color);
    put('placas', placas);
    put('serie', serie);
    put('calidad', calidad);
    put('motivo_relacion', motivoRelacion);
    put('numero_reporte_robo', numeroReporteRobo);
    put('observaciones', observaciones);
    if (conReporteRobo) fields['vehiculos[$index][con_reporte_robo]'] = '1';
  }

  void dispose() {
    for (final controller in [
      tipo,
      marca,
      submarca,
      modelo,
      color,
      placas,
      serie,
      calidad,
      motivoRelacion,
      numeroReporteRobo,
      observaciones,
    ]) {
      controller.dispose();
    }
  }
}

class _ObjetoFields {
  final tipoObjeto = TextEditingController();
  final descripcion = TextEditingController();
  final cantidad = TextEditingController();
  final unidadMedida = TextEditingController();
  final cadenaCustodia = TextEditingController();
  final observaciones = TextEditingController();

  bool get hasAny => [
    tipoObjeto,
    descripcion,
    cantidad,
    unidadMedida,
    cadenaCustodia,
    observaciones,
  ].any((controller) => controller.text.trim().isNotEmpty);

  void write(Map<String, String> fields, int index) {
    void put(String key, TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) fields['objetos[$index][$key]'] = text;
    }

    put('tipo_objeto', tipoObjeto);
    put('descripcion', descripcion);
    put('cantidad', cantidad);
    put('unidad_medida', unidadMedida);
    put('cadena_custodia', cadenaCustodia);
    put('observaciones', observaciones);
  }

  void dispose() {
    for (final controller in [
      tipoObjeto,
      descripcion,
      cantidad,
      unidadMedida,
      cadenaCustodia,
      observaciones,
    ]) {
      controller.dispose();
    }
  }
}

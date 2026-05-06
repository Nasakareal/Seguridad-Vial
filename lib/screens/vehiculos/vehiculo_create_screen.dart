import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/routes.dart';
import '../../core/vehiculos/vehiculo_taxonomia.dart';
import '../../core/vehiculos/aseguradoras_vehiculo.dart';
import '../../core/vehiculos/colores_vehiculo.dart';
import '../../core/vehiculos/estados_republica.dart';
import '../../services/local_draft_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/vehiculo_form_service.dart';
import '../../services/gruas_catalog_service.dart';

class VehiculoCreateScreen extends StatefulWidget {
  const VehiculoCreateScreen({super.key});

  @override
  State<VehiculoCreateScreen> createState() => _VehiculoCreateScreenState();
}

class _VehiculoCreateScreenState extends State<VehiculoCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _draftHydrated = false;
  LocalDraftAutosave? _draft;

  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();

  String? _tipoGeneralSeleccionado;
  String? _tipoCarroceriaSeleccionada;

  final _lineaCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _placasCtrl = TextEditingController();
  final _serieCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController(text: '5');
  final _tipoServicioCtrl = TextEditingController(text: 'PARTICULAR');
  final _tarjetaCirculacionNombreCtrl = TextEditingController();
  final _aseguradoraCtrl = TextEditingController();
  final _montoDanosCtrl = TextEditingController();
  final _partesDanadasCtrl = TextEditingController();
  bool _antecedenteVehiculo = false;

  String? _estadoPlacasSeleccionado;

  bool _cargandoGruas = true;
  List<Map<String, dynamic>> _gruas = [];
  int? _gruaIdSeleccionada;
  int? _corralonGruaIdSeleccionada;

  static const String _baseApi = 'https://seguridadvial-mich.com/api';

  int _hechoIdFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['hechoId'] != null) {
      return int.tryParse(args['hechoId'].toString()) ?? 0;
    }
    return 0;
  }

  String? _hechoClientUuidFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['hechoClientUuid'] != null) {
      final value = args['hechoClientUuid'].toString().trim();
      return value.isEmpty ? null : value;
    }
    return null;
  }

  List<Map<String, dynamic>> _vehiculosSnapshotFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['vehiculosSnapshot'] is List) {
      return (args['vehiculosSnapshot'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_draftHydrated) {
      _draftHydrated = true;
      _ensureDraft();
      if (!_hydrateDraftFromArgs()) {
        unawaited(_restoreLocalDraft());
      }
    }
    if (_cargandoGruas) {
      _cargarGruas();
    }
  }

  @override
  void dispose() {
    _draft?.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _lineaCtrl.dispose();
    _colorCtrl.dispose();
    _placasCtrl.dispose();
    _serieCtrl.dispose();
    _capacidadCtrl.dispose();
    _tipoServicioCtrl.dispose();
    _tarjetaCirculacionNombreCtrl.dispose();
    _aseguradoraCtrl.dispose();
    _montoDanosCtrl.dispose();
    _partesDanadasCtrl.dispose();
    super.dispose();
  }

  String _t(TextEditingController c) => c.text.trim();

  String _aseguradoraDropdownValue() {
    return AseguradorasVehiculo.valueFromAny(_t(_aseguradoraCtrl)) ?? '';
  }

  String _colorDropdownValue() {
    return ColoresVehiculo.normalizeUnknown(_t(_colorCtrl));
  }

  void _setAseguradora(String? value) {
    _aseguradoraCtrl.text = value ?? '';
  }

  void _setColor(String? value) {
    _colorCtrl.text = value ?? '';
  }

  int? _toIntOrNull(String s) {
    final v = s.trim();
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  double? _toDoubleOrNull(String s) {
    final v = s.trim();
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  String? _tipoGeneralValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Requerido';
    return null;
  }

  String? _tipoCarroceriaValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Requerido';
    return null;
  }

  Map<String, dynamic>? _tryJsonMap(String body) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _tryJsonMapFromNullable(String? body) {
    final text = (body ?? '').trim();
    if (text.isEmpty) return null;
    return _tryJsonMap(text);
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  Map<String, dynamic>? _createdVehiculoFromResult(OfflineActionResult result) {
    final response = _tryJsonMapFromNullable(result.responseBody);
    final data = response?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  int _createdVehiculoIdFromResult(OfflineActionResult result) {
    final response = _tryJsonMapFromNullable(result.responseBody);
    if (response == null) return 0;

    final meta = response['meta'];
    if (meta is Map) {
      final id = _toInt(meta['id']);
      if (id > 0) return id;
    }

    final data = response['data'];
    if (data is Map) {
      final id = _toInt(data['id']);
      if (id > 0) return id;
    }

    return _toInt(response['id']);
  }

  List<Map<String, dynamic>> _vehiculosSnapshotWithCreated(
    List<Map<String, dynamic>> current,
    Map<String, dynamic>? created,
  ) {
    if (created == null) return current;

    final createdId = _toInt(created['id']);
    if (createdId <= 0) return current;

    final next = current
        .where((vehiculo) => _toInt(vehiculo['id']) != createdId)
        .toList();
    next.add(created);
    return next;
  }

  Future<void> _cargarGruas() async {
    try {
      final gruas = await GruasCatalogService.fetchVisibleGruas();
      if (!mounted) return;
      setState(() {
        _gruas = gruas;
        if (!GruasCatalogService.containsId(_gruas, _gruaIdSeleccionada)) {
          _gruaIdSeleccionada = null;
        }
        if (!GruasCatalogService.containsId(
          _gruas,
          _corralonGruaIdSeleccionada,
        )) {
          _corralonGruaIdSeleccionada = null;
        }
        _cargandoGruas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoGruas = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar grúas: $e')),
      );
    }
  }

  void _ensureDraft() {
    _draft ??= LocalDraftAutosave(draftId: _draftId(), collect: _draftValues)
      ..attachTextControllers({
        'marca': _marcaCtrl,
        'modelo': _modeloCtrl,
        'linea': _lineaCtrl,
        'color': _colorCtrl,
        'placas': _placasCtrl,
        'serie': _serieCtrl,
        'capacidad': _capacidadCtrl,
        'tipo_servicio': _tipoServicioCtrl,
        'tarjeta_circulacion_nombre': _tarjetaCirculacionNombreCtrl,
        'aseguradora': _aseguradoraCtrl,
        'monto_danos': _montoDanosCtrl,
        'partes_danadas': _partesDanadasCtrl,
      });
  }

  String _draftId() {
    final hechoId = _hechoIdFromArgs(context);
    final hechoClientUuid = _hechoClientUuidFromArgs(context) ?? '';
    return 'vehiculos:create:$hechoId:$hechoClientUuid';
  }

  bool _hydrateDraftFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map || args['offlineDraft'] is! Map) return false;

    final draft = Map<String, dynamic>.from(args['offlineDraft'] as Map);
    final body = draft['body'] is Map
        ? Map<String, dynamic>.from(draft['body'] as Map)
        : const <String, dynamic>{};

    _applyDraftBody(body);
    return true;
  }

  Future<void> _restoreLocalDraft() async {
    final restored = await _draft?.restore(_applyLocalDraft) ?? false;
    if (!mounted || !restored) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Borrador local recuperado.')));
  }

  void _applyLocalDraft(Map<String, dynamic> draft) {
    _applyDraftBody(draft);
  }

  void _applyDraftBody(Map<String, dynamic> body) {
    _marcaCtrl.text = (body['marca'] ?? '').toString();
    _modeloCtrl.text = (body['modelo'] ?? '').toString();
    _lineaCtrl.text = (body['linea'] ?? '').toString();
    _colorCtrl.text = (body['color'] ?? '').toString();
    _placasCtrl.text = (body['placas'] ?? '').toString();
    _serieCtrl.text = (body['serie'] ?? '').toString();
    _capacidadCtrl.text = (body['capacidad_personas'] ?? '5').toString();
    _tipoServicioCtrl.text = VehiculoFormService.tipoServicioPlacaValue(
      (body['tipo_servicio'] ?? '').toString(),
    );
    _tarjetaCirculacionNombreCtrl.text =
        (body['tarjeta_circulacion_nombre'] ?? '').toString();
    _aseguradoraCtrl.text =
        AseguradorasVehiculo.valueFromAny(
          (body['aseguradora'] ?? '').toString(),
        ) ??
        '';
    _montoDanosCtrl.text = (body['monto_danos'] ?? '').toString();
    _partesDanadasCtrl.text = (body['partes_danadas'] ?? '').toString();
    _antecedenteVehiculo = _toBool(body['antecedente_vehiculo']);
    _estadoPlacasSeleccionado = EstadosRepublica.valueFromAny(
      (body['estado_placas'] ?? '').toString(),
    );
    _tipoGeneralSeleccionado = _blankToNull(body['tipo_general']);
    _tipoCarroceriaSeleccionada = _blankToNull(body['tipo']);
    _tipoGeneralSeleccionado ??= _inferirTipoGeneralPorCarroceria(
      _tipoCarroceriaSeleccionada,
    );
    _gruaIdSeleccionada = _intValue(body['grua_id']);
    _corralonGruaIdSeleccionada = _intValue(body['corralon_id']);
  }

  Map<String, dynamic> _draftValues() {
    return <String, dynamic>{
      'marca': _marcaCtrl.text,
      'modelo': _modeloCtrl.text,
      'tipo_general': _tipoGeneralSeleccionado,
      'tipo': _tipoCarroceriaSeleccionada,
      'linea': _lineaCtrl.text,
      'color': _colorCtrl.text,
      'placas': _placasCtrl.text,
      'estado_placas': _estadoPlacasSeleccionado,
      'serie': _serieCtrl.text,
      'capacidad_personas': _capacidadCtrl.text,
      'tipo_servicio': VehiculoFormService.tipoServicioPlacaValue(
        _tipoServicioCtrl.text,
      ),
      'tarjeta_circulacion_nombre': _tarjetaCirculacionNombreCtrl.text,
      'grua_id': _gruaIdSeleccionada,
      'corralon_id': _corralonGruaIdSeleccionada,
      'aseguradora': _aseguradoraCtrl.text,
      'monto_danos': _montoDanosCtrl.text,
      'partes_danadas': _partesDanadasCtrl.text,
      'antecedente_vehiculo': _antecedenteVehiculo,
    };
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString().trim());
  }

  String? _blankToNull(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  void _markDraftChanged() {
    _draft?.notifyChanged();
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    final raw = value?.toString().trim().toLowerCase() ?? '';
    return raw == '1' || raw == 'true' || raw == 'si' || raw == 'sí';
  }

  List<String> _carroceriasDeTipoGeneral(String? tipoGeneral) {
    return VehiculoTaxonomia.carroceriasDeTipoGeneral(tipoGeneral);
  }

  String? _inferirTipoGeneralPorCarroceria(String? carroceria) {
    final current = (carroceria ?? '').trim();
    if (current.isEmpty) return null;

    for (final entry in VehiculoTaxonomia.carrocerias.entries) {
      for (final option in entry.value) {
        if (option.toUpperCase() == current.toUpperCase()) {
          return entry.key;
        }
      }
    }

    return null;
  }

  String? _nombreGruaById(int? id) {
    if (id == null) return null;
    for (final g in _gruas) {
      final gid = int.tryParse((g['id'] ?? '').toString());
      if (gid == id) {
        final nombre = (g['nombre'] ?? '').toString().trim();
        return nombre.isEmpty ? null : nombre;
      }
    }
    return null;
  }

  Future<void> _scanTarjetaCirculacion() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const _TarjetaCirculacionScannerScreen(),
      ),
    );
    final text = raw?.trim() ?? '';
    if (text.isEmpty || !mounted) return;

    final parsed = VehiculoFormService.parseTarjetaCirculacionQr(text);
    final applied = _applyTarjetaCirculacionData(parsed);

    if (!mounted) return;
    if (applied > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se llenaron $applied campos desde el QR.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('QR leído'),
        content: const Text(
          'No pude identificar campos del vehículo en este QR. Puedes capturar manualmente o compartirnos un ejemplo del texto crudo para ajustar el lector.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  int _applyTarjetaCirculacionData(VehiculoQrData parsed) {
    var applied = 0;

    bool setText(TextEditingController controller, String? value) {
      final cleaned = (value ?? '').trim();
      if (cleaned.isEmpty || controller.text.trim() == cleaned) return false;
      controller.text = cleaned;
      return true;
    }

    setState(() {
      if (setText(_marcaCtrl, parsed.marca)) applied += 1;
      if (setText(_lineaCtrl, parsed.linea)) applied += 1;
      if (setText(_modeloCtrl, parsed.modelo)) applied += 1;
      if (setText(_colorCtrl, parsed.color)) applied += 1;
      if (setText(_placasCtrl, parsed.placas)) applied += 1;
      if (setText(_serieCtrl, parsed.serie)) applied += 1;
      final tipoServicio = VehiculoFormService.normalizeTipoServicioPlaca(
        parsed.tipoServicio,
      );
      if (setText(_tipoServicioCtrl, tipoServicio)) applied += 1;
      if (setText(
        _tarjetaCirculacionNombreCtrl,
        parsed.tarjetaCirculacionNombre,
      )) {
        applied += 1;
      }

      final estado = parsed.estadoPlacas;
      if ((estado ?? '').trim().isNotEmpty &&
          _estadoPlacasSeleccionado != estado) {
        _estadoPlacasSeleccionado = estado;
        applied += 1;
      }

      final tipoGeneral = parsed.tipoGeneral;
      if (_isTipoGeneralDisponible(tipoGeneral) &&
          _tipoGeneralSeleccionado != tipoGeneral) {
        _tipoGeneralSeleccionado = tipoGeneral;
        applied += 1;
      }

      final tipoCarroceria = parsed.tipoCarroceria;
      if (_isCarroceriaDisponible(_tipoGeneralSeleccionado, tipoCarroceria) &&
          _tipoCarroceriaSeleccionada != tipoCarroceria) {
        _tipoCarroceriaSeleccionada = tipoCarroceria;
        applied += 1;
      }
    });

    if (applied > 0) _markDraftChanged();
    return applied;
  }

  bool _isTipoGeneralDisponible(String? value) {
    final current = (value ?? '').trim();
    if (current.isEmpty) return false;
    return VehiculoTaxonomia.tiposGenerales.any(
      (item) => item['value'] == current,
    );
  }

  bool _isCarroceriaDisponible(String? tipoGeneral, String? carroceria) {
    final current = (carroceria ?? '').trim();
    if (current.isEmpty) return false;
    return _carroceriasDeTipoGeneral(tipoGeneral).contains(current);
  }

  Future<void> _scrollToContext(BuildContext targetContext) {
    return Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  Future<void> _scrollToFirstInvalidField(
    Iterable<FormFieldState<Object?>> invalidFields,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    final firstInvalid = invalidFields.isEmpty ? null : invalidFields.first;
    final targetContext = firstInvalid?.context;
    if (targetContext == null) return;
    if (!targetContext.mounted) return;

    await _scrollToContext(targetContext);
  }

  Future<bool> _validateFormAndScroll() async {
    final invalidFields =
        _formKey.currentState?.validateGranularly() ??
        const <FormFieldState<Object?>>{};
    if (invalidFields.isEmpty) return true;

    await _scrollToFirstInvalidField(invalidFields);
    return false;
  }

  Future<void> _guardar({
    required int hechoId,
    required String? hechoClientUuid,
  }) async {
    final normalizedHechoClientUuid = (hechoClientUuid ?? '').trim();
    final vehiculosSnapshot = _vehiculosSnapshotFromArgs(context);
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (hechoId <= 0 && normalizedHechoClientUuid.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Error'),
          content: Text(
            'Falta el contexto del hecho para guardar el vehículo.',
          ),
        ),
      );
      return;
    }

    if (!await _validateFormAndScroll()) return;

    final tipoServicio = VehiculoFormService.tipoServicioPlacaValue(
      _t(_tipoServicioCtrl),
    );
    final validationError = VehiculoFormService.validateVehiculoBeforeSubmit(
      marca: _t(_marcaCtrl),
      linea: _t(_lineaCtrl),
      color: _t(_colorCtrl),
      tipoServicio: tipoServicio,
      partesDanadas: _t(_partesDanadasCtrl),
      tipoGeneral: _tipoGeneralSeleccionado,
      tipoCarroceria: _tipoCarroceriaSeleccionada,
      placas: _t(_placasCtrl),
      estadoPlacas: _estadoPlacasSeleccionado,
      serie: _t(_serieCtrl),
      capacidad: _t(_capacidadCtrl),
      montoDanos: _t(_montoDanosCtrl),
      modelo: _t(_modeloCtrl),
      tarjetaCirculacionNombre: _t(_tarjetaCirculacionNombreCtrl),
      aseguradora: _t(_aseguradoraCtrl),
    );
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final duplicateError =
        await VehiculoFormService.validateVehiculoDuplicatesWithinHecho(
          hechoId: hechoId,
          hechoClientUuid: normalizedHechoClientUuid,
          existingVehiculos: vehiculosSnapshot,
          placas: _t(_placasCtrl),
          serie: _t(_serieCtrl),
        );
    if (duplicateError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(duplicateError)));
      return;
    }

    setState(() => _saving = true);

    try {
      final draftOpId = routeArgs is Map
          ? (routeArgs['offlineDraft'] is Map
                ? (routeArgs['offlineDraft'] as Map)['id']
                : null)
          : null;
      final clientUuid = (draftOpId ?? '').toString().trim().isNotEmpty
          ? (draftOpId ?? '').toString().trim()
          : OfflineSyncService.newClientUuid();
      final uri = Uri.parse('$_baseApi/vehiculos');
      final corralonNombre = _nombreGruaById(_corralonGruaIdSeleccionada);

      final placasClean = VehiculoFormService.normalizePlacas(_t(_placasCtrl));

      final estadoClean = VehiculoFormService.normalizeEstadoPlacas(
        _estadoPlacasSeleccionado,
      );

      final payload = <String, dynamic>{
        'client_uuid': clientUuid,
        if (hechoId > 0) 'hecho_id': hechoId,
        if (hechoId <= 0 && normalizedHechoClientUuid.isNotEmpty)
          'hecho_client_uuid': normalizedHechoClientUuid,
        'marca': _t(_marcaCtrl),
        'modelo': _t(_modeloCtrl).isEmpty ? null : _t(_modeloCtrl),
        'tipo': _tipoCarroceriaSeleccionada,
        'linea': _t(_lineaCtrl),
        'color': _t(_colorCtrl),
        'placas': placasClean.isEmpty ? null : placasClean,
        'estado_placas': placasClean.isEmpty ? null : estadoClean,
        'serie': VehiculoFormService.normalizeSerie(_t(_serieCtrl)),
        'capacidad_personas': _toIntOrNull(_t(_capacidadCtrl)) ?? 0,
        'tipo_servicio': tipoServicio,
        'tarjeta_circulacion_nombre': _t(_tarjetaCirculacionNombreCtrl).isEmpty
            ? null
            : _t(_tarjetaCirculacionNombreCtrl),
        'grua_id': _gruaIdSeleccionada,
        'corralon': (corralonNombre == null || corralonNombre.isEmpty)
            ? null
            : corralonNombre,
        'aseguradora': _t(_aseguradoraCtrl).isEmpty
            ? null
            : _t(_aseguradoraCtrl),
        'monto_danos': _toDoubleOrNull(_t(_montoDanosCtrl)) ?? 0,
        'partes_danadas': _t(_partesDanadasCtrl),
        'antecedente_vehiculo': _antecedenteVehiculo,
      };

      final result = await OfflineSyncService.submitJson(
        label: 'Vehículo',
        method: 'POST',
        uri: uri,
        body: payload,
        requestId: clientUuid,
        dependsOnOperationId: hechoId > 0 ? null : normalizedHechoClientUuid,
        successCodes: const <int>{200, 201},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));

      final createdVehiculoId = _createdVehiculoIdFromResult(result);
      if (result.synced && hechoId > 0 && createdVehiculoId > 0) {
        final createdVehiculo = _createdVehiculoFromResult(result);
        await _draft?.discard();
        if (!mounted) return;
        await Navigator.pushReplacementNamed(
          context,
          AppRoutes.vehiculoConductorCreate,
          arguments: {
            'hechoId': hechoId,
            'vehiculoId': createdVehiculoId,
            'vehiculosSnapshot': _vehiculosSnapshotWithCreated(
              vehiculosSnapshot,
              createdVehiculo,
            ),
          },
        );
        return;
      }

      await _draft?.discard();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo guardar el vehículo.\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hechoId = _hechoIdFromArgs(context);
    final hechoClientUuid = _hechoClientUuidFromArgs(context);
    final pendingParent =
        hechoId <= 0 && (hechoClientUuid?.trim().isNotEmpty ?? false);
    final carroceriasDisponibles = _carroceriasDeTipoGeneral(
      _tipoGeneralSeleccionado,
    );
    final tienePlacas = _t(_placasCtrl).isNotEmpty;
    final aseguradoraSeleccionada = _aseguradoraDropdownValue();
    final colorSeleccionado = _colorDropdownValue();
    final coloresDisponibles = ColoresVehiculo.opcionesConActual(
      colorSeleccionado,
    );

    if (!tienePlacas && _estadoPlacasSeleccionado != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _estadoPlacasSeleccionado = null);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          pendingParent
              ? 'Nuevo vehículo (Hecho pendiente)'
              : 'Nuevo vehículo (Hecho #$hechoId)',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (pendingParent)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'Este hecho todavía no tiene ID de servidor. El vehículo se guardará con el UUID local del hecho y se sincronizará en cuanto el hecho padre suba primero.',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _scanTarjetaCirculacion,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear tarjeta de circulación'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _marcaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Marca *',
                  prefixIcon: Icon(Icons.local_offer),
                ),
                validator: (v) => VehiculoFormService.validateRequiredText(
                  v,
                  max: 50,
                  label: 'Marca',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _tipoGeneralSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Vehículo *',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('-- Seleccione --'),
                  ),
                  ...VehiculoTaxonomia.tiposGenerales.map((t) {
                    return DropdownMenuItem<String>(
                      value: t['value'],
                      child: Text(t['label'] ?? ''),
                    );
                  }),
                ],
                onChanged: (v) {
                  setState(() {
                    _tipoGeneralSeleccionado = v;
                    _tipoCarroceriaSeleccionada = null;
                  });
                  _markDraftChanged();
                },
                validator: _tipoGeneralValidator,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _tipoCarroceriaSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Carrocería *',
                  prefixIcon: Icon(Icons.merge_type),
                ),
                items: carroceriasDisponibles.isEmpty
                    ? const [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            '-- Seleccione un tipo general primero --',
                          ),
                        ),
                      ]
                    : [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('-- Seleccione --'),
                        ),
                        ...carroceriasDisponibles.map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          );
                        }),
                      ],
                onChanged: carroceriasDisponibles.isEmpty
                    ? null
                    : (v) {
                        setState(() => _tipoCarroceriaSeleccionada = v);
                        _markDraftChanged();
                      },
                validator: (v) {
                  if ((_tipoGeneralSeleccionado ?? '').isEmpty) return null;
                  return _tipoCarroceriaValidator(v);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _lineaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Línea *',
                  prefixIcon: Icon(Icons.text_fields),
                ),
                validator: (v) => VehiculoFormService.validateRequiredText(
                  v,
                  max: 50,
                  label: 'Línea',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _modeloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Modelo (opcional, máx 10)',
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                validator: (v) => VehiculoFormService.validateOptionalText(
                  v,
                  max: 10,
                  label: 'Modelo',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: colorSeleccionado.isEmpty ? null : colorSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Color *',
                  prefixIcon: Icon(Icons.color_lens),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('-- Seleccione --'),
                  ),
                  ...coloresDisponibles.map((color) {
                    return DropdownMenuItem<String>(
                      value: color,
                      child: Text(color),
                    );
                  }),
                ],
                onChanged: (v) {
                  setState(() => _setColor(v));
                  _markDraftChanged();
                },
                validator: (v) => VehiculoFormService.validateRequiredText(
                  v,
                  max: 30,
                  label: 'Color',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _placasCtrl,
                decoration: const InputDecoration(
                  labelText: 'Placas (opcional)',
                  prefixIcon: Icon(Icons.credit_card),
                ),
                validator: VehiculoFormService.validatePlacas,
                onChanged: (_) {
                  setState(() {});
                  _markDraftChanged();
                },
              ),
              if (tienePlacas) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _estadoPlacasSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Estado de placas *',
                    prefixIcon: Icon(Icons.map),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('-- Seleccione --'),
                    ),
                    ...EstadosRepublica.estados.map((e) {
                      return DropdownMenuItem<String>(
                        value: e['value'],
                        child: Text(e['label'] ?? ''),
                      );
                    }),
                  ],
                  onChanged: (v) {
                    setState(() => _estadoPlacasSeleccionado = v);
                    _markDraftChanged();
                  },
                  validator: (v) {
                    if (!tienePlacas) return null;
                    if ((v ?? '').trim().isEmpty) {
                      return 'Requerido si capturas placas';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _serieCtrl,
                decoration: const InputDecoration(
                  labelText: 'No. Serie (opcional, máx 17)',
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                validator: VehiculoFormService.validateSerie,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _capacidadCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacidad de personas *',
                  prefixIcon: Icon(Icons.people),
                ),
                validator: VehiculoFormService.validateCapacidad,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: VehiculoFormService.tipoServicioPlacaValue(
                  _tipoServicioCtrl.text,
                ),
                decoration: const InputDecoration(
                  labelText: 'Tipo de servicio de placa *',
                  prefixIcon: Icon(Icons.miscellaneous_services),
                ),
                items: VehiculoFormService.tiposServicioPlaca
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _tipoServicioCtrl.text = value);
                  _markDraftChanged();
                },
                validator: VehiculoFormService.validateTipoServicioPlaca,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _tarjetaCirculacionNombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre tarjeta circulación (opcional, máx 60)',
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) => VehiculoFormService.validateOptionalText(
                  v,
                  max: 60,
                  label: 'Nombre en tarjeta de circulación',
                ),
              ),
              const SizedBox(height: 10),
              _cargandoGruas
                  ? const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('Cargando grúas...'),
                    )
                  : DropdownButtonFormField<int?>(
                      value: _gruaIdSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Grúa (empresa)',
                        prefixIcon: Icon(Icons.local_shipping),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('SIN GRÚA / N/A'),
                        ),
                        ..._gruas.map((g) {
                          final id = GruasCatalogService.idOf(g);
                          return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(
                              GruasCatalogService.displayName(g),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        setState(() => _gruaIdSeleccionada = v);
                        _markDraftChanged();
                      },
                    ),
              const SizedBox(height: 10),
              _cargandoGruas
                  ? const SizedBox.shrink()
                  : DropdownButtonFormField<int?>(
                      value: _corralonGruaIdSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Corralón (empresa)',
                        prefixIcon: Icon(Icons.warehouse),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('SIN CORRALÓN / N/A'),
                        ),
                        ..._gruas.map((g) {
                          final id = GruasCatalogService.idOf(g);
                          return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(
                              GruasCatalogService.displayName(
                                g,
                                fallbackPrefix: 'CORRALÓN',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        setState(() => _corralonGruaIdSeleccionada = v);
                        _markDraftChanged();
                      },
                    ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: aseguradoraSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Aseguradora (opcional)',
                  prefixIcon: Icon(Icons.security),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Ninguna'),
                  ),
                  ...AseguradorasVehiculo.opciones.map((aseguradora) {
                    return DropdownMenuItem<String>(
                      value: aseguradora,
                      child: Text(aseguradora),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _setAseguradora(value));
                  _markDraftChanged();
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _montoDanosCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto daños *',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (v) =>
                    VehiculoFormService.validateMonto(v, required: true),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _partesDanadasCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Partes dañadas *',
                  prefixIcon: Icon(Icons.car_crash),
                ),
                validator: (v) => VehiculoFormService.validateRequiredText(
                  v,
                  max: 10000,
                  label: 'Partes dañadas',
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                title: const Text('Antecedente del vehículo'),
                value: _antecedenteVehiculo,
                onChanged: (v) {
                  setState(() => _antecedenteVehiculo = v);
                  _markDraftChanged();
                },
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _saving
                    ? null
                    : () => _guardar(
                        hechoId: hechoId,
                        hechoClientUuid: hechoClientUuid,
                      ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Guardando...' : 'Guardar vehículo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaCirculacionScannerScreen extends StatefulWidget {
  const _TarjetaCirculacionScannerScreen();

  @override
  State<_TarjetaCirculacionScannerScreen> createState() =>
      _TarjetaCirculacionScannerScreenState();
}

class _TarjetaCirculacionScannerScreenState
    extends State<_TarjetaCirculacionScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true,
  );

  bool _handled = false;

  void _handleDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isEmpty) continue;

      _handled = true;
      unawaited(_controller.stop());
      if (!mounted) return;
      Navigator.pop(context, raw);
      return;
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear tarjeta'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Cambiar cámara',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No se pudo iniciar la cámara.\n\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.72),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: const Text(
                'Apunta al QR de la tarjeta de circulación. Se llenarán los campos que se puedan reconocer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

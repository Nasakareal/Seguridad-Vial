import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/hechos/hechos_catalogos.dart';
import '../../../models/dictamen_item.dart';
import '../../../models/hecho_form_data.dart';
import '../../../services/auth_service.dart';
import '../../../services/hechos_form_service.dart';
import '../../../services/local_draft_service.dart';
import '../../../services/offline_sync_service.dart';
import '../../../services/reverse_geocode_service.dart';
import '../../../widgets/landscape_photo_crop_screen.dart';
import 'ubicacion_card.dart';
import 'photo_card.dart';
import 'danos_patrimoniales_card.dart';
import 'dictamen_selector.dart';

enum HechoFormMode { create, edit }

class HechoForm extends StatefulWidget {
  final HechoFormMode mode;
  final HechoFormData data;
  final File? initialFotoLugar;
  final File? initialFotoSituacion;
  final String? draftId;
  final Future<OfflineActionResult> Function({
    required HechoFormData data,
    required DictamenItem? dictamenSelected,
    required File? fotoLugar,
    required File? fotoSituacion,
  })
  onSubmit;
  final Future<void> Function(OfflineActionResult result, HechoFormData data)?
  onSubmitted;

  const HechoForm({
    super.key,
    required this.mode,
    required this.data,
    this.initialFotoLugar,
    this.initialFotoSituacion,
    this.draftId,
    required this.onSubmit,
    this.onSubmitted,
  });

  @override
  State<HechoForm> createState() => _HechoFormState();
}

class _HechoFormState extends State<HechoForm> {
  final _formKey = GlobalKey<FormState>();
  final _horaFieldKey = GlobalKey();
  final _fechaFieldKey = GlobalKey();
  final _fotoLugarKey = GlobalKey();
  final _fotoSituacionKey = GlobalKey();
  final _danosKey = GlobalKey();
  final _folioFieldKey = GlobalKey();
  bool _submitting = false;
  bool _isPerito = false;
  bool _loadingRoleFlags = true;
  bool _usesRelaxedHechosRules = false;
  bool _hideDelegacionesAdminFields = false;
  bool _canUseDictamenes = false;

  TimeOfDay? _hora;
  DateTime? _fecha;

  final _folioCtrl = TextEditingController();
  final _peritoCtrl = TextEditingController();
  final _authPracCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();

  final _calleCtrl = TextEditingController();
  final _coloniaCtrl = TextEditingController();
  final _entreCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();

  final _vehMpCtrl = TextEditingController();
  final _persMpCtrl = TextEditingController();

  final _propsCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();

  final _picker = ImagePicker();
  File? _fotoLugar;
  File? _fotoSituacion;

  DictamenItem? _dictamenSelected;
  LocalDraftAutosave? _draft;

  @override
  void initState() {
    super.initState();
    _syncFromData();
    _initDraft();
    _loadRoleFlags();
  }

  @override
  void didUpdateWidget(covariant HechoForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _syncFromData();
    }
  }

  void _syncFromData() {
    final d = widget.data;

    _hora = d.hora;
    _fecha = d.fecha;

    _folioCtrl.text = d.folioC5i;
    _peritoCtrl.text = d.perito;
    _authPracCtrl.text = d.autorizacionPractico;
    _unidadCtrl.text = d.unidad;

    _calleCtrl.text = d.calle;
    _coloniaCtrl.text = d.colonia;
    _entreCtrl.text = d.entreCalles;
    _municipioCtrl.text = d.municipio;

    _vehMpCtrl.text = d.vehiculosMp;
    _persMpCtrl.text = d.personasMp;

    _propsCtrl.text = d.propiedadesAfectadas;
    _montoCtrl.text = d.montoDanos;

    _fotoLugar ??= widget.initialFotoLugar;
    _fotoSituacion ??= widget.initialFotoSituacion;
  }

  Future<void> _loadRoleFlags() async {
    final isPerito = await AuthService.isPerito();
    final usesRelaxedHechosRules =
        await AuthService.isHechosCaptureRelaxedUser();
    final hideDelegacionesAdminFields =
        await AuthService.hideDelegacionesHechoAdminFields();
    final isDelegaciones = await AuthService.isDelegacionesUser();
    final canUseDictamenes =
        !isDelegaciones && await AuthService.isSiniestrosUser();
    if (!mounted) return;

    setState(() {
      _isPerito = isPerito;
      _loadingRoleFlags = false;
      _usesRelaxedHechosRules = usesRelaxedHechosRules;
      _hideDelegacionesAdminFields = hideDelegacionesAdminFields;
      _canUseDictamenes = canUseDictamenes;
      if (_usesRelaxedHechosRules) {
        widget.data.sector = null;
      }
      if (_isPerito) {
        _hora = HechosFormService.currentTime();
        widget.data.hora = _hora;
      }
      if (_hideDelegacionesAdminFields) {
        _hora ??= widget.data.hora ?? HechosFormService.currentTime();
        _fecha ??= widget.data.fecha ?? DateTime.now();
        widget.data.hora = _hora;
        widget.data.fecha = _fecha;
      }
      if (!_canUseDictamenes) {
        widget.data.dictamenId = null;
        _dictamenSelected = null;
        _resetMpFields();
      }
    });
  }

  @override
  void dispose() {
    _draft?.dispose();
    _folioCtrl.dispose();
    _peritoCtrl.dispose();
    _authPracCtrl.dispose();
    _unidadCtrl.dispose();
    _calleCtrl.dispose();
    _coloniaCtrl.dispose();
    _entreCtrl.dispose();
    _municipioCtrl.dispose();
    _vehMpCtrl.dispose();
    _persMpCtrl.dispose();
    _propsCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  void _initDraft() {
    final draftId = widget.draftId;
    if (draftId == null || draftId.trim().isEmpty) return;
    _draft = LocalDraftAutosave(draftId: draftId, collect: _draftValues)
      ..attachTextControllers({
        'folio_c5i': _folioCtrl,
        'perito': _peritoCtrl,
        'autorizacion_practico': _authPracCtrl,
        'unidad': _unidadCtrl,
        'calle': _calleCtrl,
        'colonia': _coloniaCtrl,
        'entre_calles': _entreCtrl,
        'municipio': _municipioCtrl,
        'vehiculos_mp': _vehMpCtrl,
        'personas_mp': _persMpCtrl,
        'propiedades_afectadas': _propsCtrl,
        'monto_danos': _montoCtrl,
      });
    unawaited(_restoreLocalDraft());
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
    final d = widget.data;
    d.clientUuid = _blankToNull(draft['client_uuid']);
    d.folioC5i = _str(draft['folio_c5i']);
    d.perito = _str(draft['perito']);
    d.autorizacionPractico = _str(draft['autorizacion_practico']);
    d.unidad = _str(draft['unidad']);
    d.unidadOrgId = _str(draft['unidad_org_id']);
    d.hora = _parseTime(draft['hora']);
    d.fecha = DateTime.tryParse(_str(draft['fecha']));
    d.sector = _blankToNull(draft['sector']);
    d.calle = _str(draft['calle']);
    d.colonia = _str(draft['colonia']);
    d.entreCalles = _str(draft['entre_calles']);
    d.municipio = _str(draft['municipio']);
    d.tipoHecho = _blankToNull(draft['tipo_hecho']);
    d.superficieVia = _blankToNull(draft['superficie_via']);
    d.tiempo = _blankToNull(draft['tiempo']);
    d.clima = _blankToNull(draft['clima']);
    d.condiciones = _blankToNull(draft['condiciones']);
    d.controlTransito = _blankToNull(draft['control_transito']);
    d.checaronAntecedentes = _boolValue(draft['checaron_antecedentes']);
    d.causa = _blankToNull(draft['causas']);
    d.responsable = _str(draft['responsable']);
    d.colisionCamino = _blankToNull(draft['colision_camino']);
    d.situacion = _blankToNull(draft['situacion']);
    d.vehiculosMp = _str(draft['vehiculos_mp'], fallback: '0');
    d.personasMp = _str(draft['personas_mp'], fallback: '0');
    d.vehiculosEsperados = _str(
      draft['vehiculos_esperados'],
      fallback: d.vehiculosEsperados,
    );
    d.conductoresEsperados = _str(
      draft['conductores_esperados'],
      fallback: d.conductoresEsperados,
    );
    d.lesionadosEsperados = _str(
      draft['lesionados_esperados'],
      fallback: d.lesionadosEsperados,
    );
    d.danosPatrimoniales = _boolValue(draft['danos_patrimoniales']);
    d.propiedadesAfectadas = _str(draft['propiedades_afectadas']);
    d.montoDanos = _str(draft['monto_danos']);
    d.lat = _doubleValue(draft['lat']);
    d.lng = _doubleValue(draft['lng']);
    d.calidadGeo = _blankToNull(draft['calidad_geo']);
    d.notaGeo = _blankToNull(draft['nota_geo']);
    d.fuenteUbicacion = _blankToNull(draft['fuente_ubicacion']);
    d.ubicacionFormateada = _blankToNull(draft['ubicacion_formateada']);
    d.placeId = _blankToNull(draft['place_id']);
    d.dictamenId = _intValue(draft['dictamen_id']);

    final fotoLugarPath = _blankToNull(draft['foto_lugar_path']);
    if (fotoLugarPath != null) {
      final file = File(fotoLugarPath);
      if (file.existsSync()) _fotoLugar = file;
    }
    final fotoSituacionPath = _blankToNull(draft['foto_situacion_path']);
    if (fotoSituacionPath != null) {
      final file = File(fotoSituacionPath);
      if (file.existsSync()) _fotoSituacion = file;
    }

    _syncFromData();
  }

  Map<String, dynamic> _draftValues() {
    final d = widget.data;
    return <String, dynamic>{
      'client_uuid': d.clientUuid,
      'folio_c5i': _folioCtrl.text,
      'perito': _peritoCtrl.text,
      'autorizacion_practico': _authPracCtrl.text,
      'unidad': _unidadCtrl.text,
      'unidad_org_id': d.unidadOrgId,
      'hora': _hora == null ? null : HechosFormService.horaStr(_hora!),
      'fecha': _fecha == null ? null : HechosFormService.ymd(_fecha!),
      'sector': d.sector,
      'calle': _calleCtrl.text,
      'colonia': _coloniaCtrl.text,
      'entre_calles': _entreCtrl.text,
      'municipio': _municipioCtrl.text,
      'tipo_hecho': d.tipoHecho,
      'superficie_via': d.superficieVia,
      'tiempo': d.tiempo,
      'clima': d.clima,
      'condiciones': d.condiciones,
      'control_transito': d.controlTransito,
      'checaron_antecedentes': d.checaronAntecedentes,
      'causas': d.causa,
      'responsable': d.responsable,
      'colision_camino': d.colisionCamino,
      'situacion': d.situacion,
      'vehiculos_mp': _vehMpCtrl.text,
      'personas_mp': _persMpCtrl.text,
      'vehiculos_esperados': d.vehiculosEsperados,
      'conductores_esperados': d.conductoresEsperados,
      'lesionados_esperados': d.lesionadosEsperados,
      'danos_patrimoniales': d.danosPatrimoniales,
      'propiedades_afectadas': _propsCtrl.text,
      'monto_danos': _montoCtrl.text,
      'lat': d.lat,
      'lng': d.lng,
      'calidad_geo': d.calidadGeo,
      'nota_geo': d.notaGeo,
      'fuente_ubicacion': d.fuenteUbicacion,
      'ubicacion_formateada': d.ubicacionFormateada,
      'place_id': d.placeId,
      'dictamen_id': d.dictamenId,
      'foto_lugar_path': _fotoLugar?.path,
      'foto_situacion_path': _fotoSituacion?.path,
    };
  }

  String _str(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString();
    return text.trim().isEmpty ? fallback : text;
  }

  String? _blankToNull(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
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

  double? _doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse((value ?? '').toString().trim());
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString().trim());
  }

  void _markDraftChanged() {
    _draft?.notifyChanged();
  }

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  String? _safeDropdownValue(String? value, List<String> options) {
    if (value == null) return null;
    final clean = value.trim();
    if (options.contains(clean)) return clean;

    final normalized = HechosCatalogos.removeAccents(clean);
    for (final option in options) {
      if (HechosCatalogos.removeAccents(option) == normalized) return option;
    }

    return null;
  }

  String? _requiredValidator(String? value) {
    return (value == null || value.trim().isEmpty) ? 'Requerido' : null;
  }

  String? _requiredMaxValidator(String? value, int max, String label) {
    final required = _requiredValidator(value);
    if (required != null) return required;
    if (value!.trim().length > max) {
      return 'Máximo $max caracteres en $label';
    }
    return null;
  }

  String? _maxLengthValidator(String? value, int max, String label) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length > max) {
      return 'Máximo $max caracteres en $label';
    }
    return null;
  }

  String? _nonNegativeIntValidator(
    String? value, {
    required String label,
    bool required = false,
    int min = 0,
  }) {
    final txt = (value ?? '').trim();
    if (txt.isEmpty) return required ? 'Requerido' : null;

    final parsed = int.tryParse(txt);
    if (parsed == null) return '$label inválido';
    if (parsed < 0) return '$label no puede ser negativo';
    if (required && parsed < min) return '$label debe ser mayor que cero';
    return null;
  }

  Future<void> _scrollToContext(BuildContext targetContext) {
    return Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    if (!targetContext.mounted) return;
    await _scrollToContext(targetContext);
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

  GlobalKey? _keyForBusinessRuleMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('foto de situación') ||
        lower.contains('foto de situacion')) {
      return _fotoSituacionKey;
    }
    if (lower.contains('foto del lugar')) return _fotoLugarKey;
    if (lower.contains('folio')) return _folioFieldKey;
    if (lower.contains('daños patrimoniales') ||
        lower.contains('propiedades afectadas') ||
        lower.contains('monto')) {
      return _danosKey;
    }
    return null;
  }

  Future<void> _pickHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? widget.data.hora ?? TimeOfDay.now(),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _hora = picked;
      widget.data.hora = picked;
    });
    _markDraftChanged();
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? widget.data.fecha ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _fecha = picked;
      widget.data.fecha = picked;
    });
    _markDraftChanged();
  }

  Future<void> _pickPhoto(bool isLugar) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (x == null || !mounted) return;

    final pickedFile = File(x.path);
    final f = isLugar
        ? await LandscapePhotoCropScreen.cropIfNeeded(context, pickedFile)
        : pickedFile;
    if (f == null) return;
    if (!mounted) return;

    setState(() {
      if (isLugar) {
        _fotoLugar = f;
      } else {
        _fotoSituacion = f;
      }
    });
    _markDraftChanged();
  }

  void _setControllerText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _resetMpFields() {
    widget.data.vehiculosMp = '0';
    widget.data.personasMp = '0';
    _setControllerText(_vehMpCtrl, '0');
    _setControllerText(_persMpCtrl, '0');
  }

  Future<String?> _autofillAddressFromCoords() async {
    final lat = widget.data.lat;
    final lng = widget.data.lng;
    if (lat == null || lng == null) return null;

    try {
      final result = await ReverseGeocodeService.lookup(lat: lat, lng: lng);
      if (!mounted) return null;

      var changed = false;

      final municipio = result.municipio == null
          ? null
          : HechosFormService.normalizeMunicipio(result.municipio!);
      if (municipio != null && municipio.trim().isNotEmpty) {
        widget.data.municipio = municipio;
        _setControllerText(_municipioCtrl, municipio);
        changed = true;
      }

      final calle = result.calle?.trim();
      if (calle != null && calle.isNotEmpty) {
        widget.data.calle = calle;
        _setControllerText(_calleCtrl, calle);
        changed = true;
      }

      final colonia = result.colonia?.trim();
      if (colonia != null && colonia.isNotEmpty) {
        widget.data.colonia = colonia;
        _setControllerText(_coloniaCtrl, colonia);
        changed = true;
      }

      widget.data.ubicacionFormateada = result.ubicacionFormateada;
      widget.data.placeId = result.placeId;

      if (changed) {
        setState(() {});
        return 'Ubicación lista y dirección autocompletada.';
      }

      return 'Ubicación lista. No se encontró una dirección útil para autocompletar.';
    } catch (_) {
      return 'Ubicación lista, pero no se pudo autocompletar la dirección.';
    }
  }

  Future<bool> _validateBusinessRules() async {
    final d = widget.data;

    if (_isPerito) {
      _hora = HechosFormService.currentTime();
      d.hora = _hora;
    }

    if (_hideDelegacionesAdminFields) {
      _hora ??= d.hora ?? HechosFormService.currentTime();
      _fecha ??= d.fecha ?? DateTime.now();
      d.hora = _hora;
      d.fecha = _fecha;
    }

    if (_hora == null) {
      await _scrollToKey(_horaFieldKey);
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona la hora.')));
      return false;
    }

    if (_fecha == null) {
      await _scrollToKey(_fechaFieldKey);
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona la fecha.')));
      return false;
    }

    if ((!_usesRelaxedHechosRules && d.sector == null) ||
        d.tipoHecho == null ||
        d.superficieVia == null ||
        d.tiempo == null ||
        d.clima == null ||
        d.condiciones == null ||
        d.controlTransito == null ||
        d.causa == null ||
        d.colisionCamino == null ||
        d.situacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos obligatorios')),
      );
      return false;
    }

    final offlineError = await HechosFormService.validateBeforeSubmit(
      data: d,
      dictamenSelected: _dictamenSelected,
      fotoLugar: _fotoLugar,
      fotoSituacion: _fotoSituacion,
      requireCoords: widget.mode == HechoFormMode.create,
    );
    if (offlineError != null) {
      final targetKey = _keyForBusinessRuleMessage(offlineError);
      if (targetKey != null) {
        await _scrollToKey(targetKey);
      }
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(offlineError)));
      return false;
    }

    return true;
  }

  void _syncToData() {
    final d = widget.data;

    d.folioC5i = _folioCtrl.text;
    d.perito = _peritoCtrl.text;
    d.autorizacionPractico = _authPracCtrl.text;
    d.unidad = _unidadCtrl.text;

    d.calle = _calleCtrl.text;
    d.colonia = _coloniaCtrl.text;
    d.entreCalles = _entreCtrl.text;
    d.municipio = HechosFormService.normalizeMunicipio(_municipioCtrl.text);

    if (_canUseDictamenes && d.situacion == 'TURNADO') {
      d.vehiculosMp = _vehMpCtrl.text;
      d.personasMp = _persMpCtrl.text;
    } else {
      d.dictamenId = null;
      _dictamenSelected = null;
      d.vehiculosMp = '0';
      d.personasMp = '0';
    }

    d.responsable =
        _safeDropdownValue(d.responsable, HechosCatalogos.responsablesUi) ??
        d.responsable;
    d.propiedadesAfectadas = _propsCtrl.text;
    d.montoDanos = _montoCtrl.text;

    d.hora = _isPerito ? HechosFormService.currentTime() : _hora;
    d.fecha = _fecha;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final invalidFields =
        _formKey.currentState?.validateGranularly() ??
        const <FormFieldState<Object?>>{};
    if (invalidFields.isNotEmpty) {
      await _scrollToFirstInvalidField(invalidFields);
      return;
    }

    _syncToData();
    if (!await _validateBusinessRules()) return;

    setState(() => _submitting = true);

    try {
      final result = await widget.onSubmit(
        data: widget.data,
        dictamenSelected: _dictamenSelected,
        fotoLugar: _fotoLugar,
        fotoSituacion: _fotoSituacion,
      );

      if (!mounted) return;
      await _draft?.discard();
      if (!mounted) return;
      if (widget.onSubmitted != null) {
        await widget.onSubmitted!(result, widget.data);
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = HechosFormService.cleanExceptionMessage(e);
      final targetKey = _keyForBusinessRuleMessage(message);
      if (targetKey != null) {
        await _scrollToKey(targetKey);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final showDelegacionesAdminFields = !_hideDelegacionesAdminFields;

    if (_loadingRoleFlags) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final sectorValue = _safeDropdownValue(
      d.sector,
      HechosCatalogos.sectoresUi,
    );
    final tipoHechoValue = _safeDropdownValue(
      d.tipoHecho,
      HechosCatalogos.tiposHecho,
    );
    final superficieViaValue = _safeDropdownValue(
      d.superficieVia,
      HechosCatalogos.superficiesViaUi,
    );
    final tiempoValue = _safeDropdownValue(d.tiempo, HechosCatalogos.tiemposUi);
    final climaValue = _safeDropdownValue(d.clima, HechosCatalogos.climasUi);
    final condicionesValue = _safeDropdownValue(
      d.condiciones,
      HechosCatalogos.condicionesUi,
    );
    final controlTransitoValue = _safeDropdownValue(
      d.controlTransito,
      HechosCatalogos.controlesTransitoUi,
    );
    final causaValue = _safeDropdownValue(d.causa, HechosCatalogos.causasUi);
    final colisionCaminoValue = _safeDropdownValue(
      d.colisionCamino,
      HechosCatalogos.colisionCaminoUi,
    );
    final responsableValue = _safeDropdownValue(
      d.responsable,
      HechosCatalogos.responsablesUi,
    );
    final situacionValue = _safeDropdownValue(
      d.situacion,
      HechosCatalogos.situaciones,
    );

    return Form(
      key: _formKey,
      child: Column(
        children: [
          UbicacionCard(
            data: d,
            disabled: _submitting,
            onChanged: () {
              setState(() {});
              _markDraftChanged();
            },
            onLocationCaptured: () async {
              final message = await _autofillAddressFromCoords();
              _markDraftChanged();
              return message;
            },
          ),
          const SizedBox(height: 12),

          DanosPatrimonialesCard(
            key: _danosKey,
            data: d,
            disabled: _submitting,
            propsCtrl: _propsCtrl,
            montoCtrl: _montoCtrl,
            onChanged: () {
              setState(() {});
              _markDraftChanged();
            },
          ),
          const SizedBox(height: 12),

          PhotoCard(
            key: _fotoLugarKey,
            title: 'Foto del hecho (opcional)',
            file: _fotoLugar,
            disabled: _submitting,
            onPick: () => _pickPhoto(true),
            onClear: () {
              setState(() => _fotoLugar = null);
              _markDraftChanged();
            },
          ),
          PhotoCard(
            key: _fotoSituacionKey,
            title: 'Foto de la situación (opcional)',
            file: _fotoSituacion,
            disabled: _submitting,
            onPick: () => _pickPhoto(false),
            onClear: () {
              setState(() => _fotoSituacion = null);
              _markDraftChanged();
            },
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: _folioFieldKey,
                  controller: _folioCtrl,
                  decoration: _dec(
                    _usesRelaxedHechosRules ? 'Folio C5i' : 'Folio C5i *',
                  ),
                  validator: (v) => _usesRelaxedHechosRules
                      ? _maxLengthValidator(v, 20, 'Folio C5i')
                      : _requiredMaxValidator(v, 20, 'Folio C5i'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _peritoCtrl,
                  decoration: _dec('Agente vial o nombre *'),
                  validator: (v) =>
                      _requiredMaxValidator(v, 255, 'Agente vial o nombre'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          if (showDelegacionesAdminFields)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _authPracCtrl,
                    decoration: _dec('Autorización Práctico'),
                    validator: (v) =>
                        _maxLengthValidator(v, 255, 'Autorización Práctico'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _unidadCtrl,
                    decoration: _dec('Unidad *'),
                    validator: (v) => _requiredMaxValidator(v, 50, 'Unidad'),
                  ),
                ),
              ],
            )
          else
            TextFormField(
              controller: _unidadCtrl,
              decoration: _dec('Unidad *'),
              validator: (v) => _requiredMaxValidator(v, 50, 'Unidad'),
            ),

          if (showDelegacionesAdminFields) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  key: _horaFieldKey,
                  child: InkWell(
                    onTap: (_submitting || _isPerito) ? null : _pickHora,
                    child: InputDecorator(
                      decoration:
                          _dec(
                            _isPerito ? 'Hora (automática)' : 'Hora *',
                          ).copyWith(
                            helperText: _isPerito
                                ? 'Para perito se usa la hora actual del servidor.'
                                : null,
                          ),
                      child: Text(
                        _hora != null
                            ? HechosFormService.horaStr(_hora!)
                            : 'Seleccionar',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  key: _fechaFieldKey,
                  child: InkWell(
                    onTap: _submitting ? null : _pickFecha,
                    child: InputDecorator(
                      decoration: _dec('Fecha *'),
                      child: Text(
                        _fecha != null
                            ? HechosFormService.ymd(_fecha!)
                            : 'Seleccionar',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!_usesRelaxedHechosRules) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: _dec('Sector *'),
              value: sectorValue,
              items: HechosCatalogos.sectoresUi
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(v, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (v) {
                      setState(() => d.sector = v);
                      _markDraftChanged();
                    },
              validator: (v) => v == null ? 'Requerido' : null,
            ),
          ],

          const SizedBox(height: 12),
          TextFormField(
            controller: _calleCtrl,
            decoration: _dec('Lugar *'),
            validator: (v) => _requiredMaxValidator(v, 255, 'Lugar'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _coloniaCtrl,
            decoration: _dec('Colonia *'),
            validator: (v) => _requiredMaxValidator(v, 255, 'Colonia'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _entreCtrl,
            decoration: _dec('Entre calles'),
            validator: (v) => _maxLengthValidator(v, 255, 'Entre calles'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _municipioCtrl,
            decoration: _dec('Municipio *'),
            validator: (v) => _requiredMaxValidator(v, 100, 'Municipio'),
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Tipo Hecho *'),
            value: tipoHechoValue,
            items: HechosCatalogos.tiposHecho
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) {
                    setState(() => d.tipoHecho = v);
                    _markDraftChanged();
                  },
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Superficie vía *'),
            value: superficieViaValue,
            items: HechosCatalogos.superficiesViaUi
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) {
                    setState(() => d.superficieVia = v);
                    _markDraftChanged();
                  },
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _dec('Tiempo *'),
                  value: tiempoValue,
                  items: HechosCatalogos.tiemposUi
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (v) {
                          setState(() => d.tiempo = v);
                          _markDraftChanged();
                        },
                  validator: (v) => v == null ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _dec('Clima *'),
                  value: climaValue,
                  items: HechosCatalogos.climasUi
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (v) {
                          setState(() => d.clima = v);
                          _markDraftChanged();
                        },
                  validator: (v) => v == null ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Condiciones *'),
            value: condicionesValue,
            items: HechosCatalogos.condicionesUi
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _submitting
                ? null
                : (v) {
                    setState(() => d.condiciones = v);
                    _markDraftChanged();
                  },
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Control tránsito *'),
            value: controlTransitoValue,
            items: HechosCatalogos.controlesTransitoUi
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) {
                    setState(() => d.controlTransito = v);
                    _markDraftChanged();
                  },
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Checaron antecedentes?'),
            value: d.checaronAntecedentes,
            onChanged: _submitting
                ? null
                : (v) {
                    setState(() => d.checaronAntecedentes = v ?? false);
                    _markDraftChanged();
                  },
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Causas *'),
            value: causaValue,
            items: HechosCatalogos.causasUi
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) {
                    setState(() => d.causa = v);
                    _markDraftChanged();
                  },
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Responsable *'),
            value: responsableValue,
            items: HechosCatalogos.responsablesUi
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) {
                    setState(() => d.responsable = v ?? '');
                    _markDraftChanged();
                  },
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Colisión camino *'),
            value: colisionCaminoValue,
            items: HechosCatalogos.colisionCaminoUi
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) {
                    setState(() => d.colisionCamino = v);
                    _markDraftChanged();
                  },
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Situación *'),
            value: situacionValue,
            items: HechosCatalogos.situaciones
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) {
                    setState(() {
                      d.situacion = v;
                      if (d.situacion != 'TURNADO' || !_canUseDictamenes) {
                        d.dictamenId = null;
                        _dictamenSelected = null;
                        _resetMpFields();
                      }
                    });
                    _markDraftChanged();
                  },
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          if (_canUseDictamenes)
            DictamenSelector(
              data: d,
              disabled: _submitting,
              onSelected: (sel) {
                _dictamenSelected = sel;
                _markDraftChanged();
              },
            ),

          if (_canUseDictamenes && d.situacion == 'TURNADO') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vehMpCtrl,
                    decoration: _dec('Vehículos MP *'),
                    keyboardType: TextInputType.number,
                    validator: (v) => _nonNegativeIntValidator(
                      v,
                      label: 'Vehículos MP',
                      required: true,
                      min: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _persMpCtrl,
                    decoration: _dec('Personas MP *'),
                    keyboardType: TextInputType.number,
                    validator: (v) => _nonNegativeIntValidator(
                      v,
                      label: 'Personas MP',
                      required: true,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.mode == HechoFormMode.create
                          ? 'Registrar Hecho'
                          : 'Guardar cambios',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

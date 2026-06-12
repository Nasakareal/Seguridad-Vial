import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/routes.dart';
import '../../core/municipios_michoacan.dart';
import '../../models/actividad.dart';
import '../../models/actividad_categoria.dart';
import '../../models/actividad_fomento.dart';
import '../../models/actividad_subcategoria.dart';
import '../../models/vialidades_urbanas_dispositivo.dart';
import '../../services/actividades_service.dart';
import '../../services/actividad_narrativa_template_service.dart';
import '../../services/auth_service.dart';
import '../../services/geo_service.dart';
import '../../services/local_draft_service.dart';
import '../../services/photo_picker_service.dart';
import '../../services/vehiculo_form_service.dart';
import '../../services/vialidades_urbanas_service.dart';
import '../../widgets/actividad_count_field.dart';
import '../../widgets/actividad_detenidos_field.dart';
import '../../widgets/actividad_people_count_guard.dart';
import '../../widgets/municipio_autocomplete_field.dart';
import '../../widgets/normalized_integer_input_formatter.dart';
import 'widgets/actividad_vehiculo_modal.dart';
import 'widgets/fomento_cultura_vial_panel.dart';

class ActividadCreateScreen extends StatefulWidget {
  const ActividadCreateScreen({super.key});

  @override
  State<ActividadCreateScreen> createState() => _ActividadCreateScreenState();
}

class _ActividadCreateScreenState extends State<ActividadCreateScreen> {
  bool _saving = false;
  bool _locating = false;
  bool _draftHydrated = false;
  bool _redirectingToHecho = false;
  bool _canEditCaptureTimestamp = false;
  bool _captureTimestampAccessLoaded = false;
  bool _isFomentoUser = false;
  bool _showVialidadesDisponibles = false;
  bool _loadingVialidadesDisponibles = false;
  String? _error;
  String? _vialidadesDisponiblesError;
  String? _userLabel;
  String? _actividadNarrativaGrupo;
  String? _clientUuid;
  String? _lastAutoNarrativa;
  bool _narrativaEditadaPorUsuario = false;
  String _locationStatus = 'Aun no se ha capturado la ubicacion.';
  Map<ActividadValidationTarget, String> _fieldErrors = {};

  List<ActividadCategoria> _categorias = [];
  List<ActividadSubcategoria> _subcategorias = [];
  List<VialidadesUrbanasDispositivo> _vialidadesDisponibles =
      const <VialidadesUrbanasDispositivo>[];

  int? _categoriaId;
  int? _subcategoriaId;
  int? _vialidadesDispositivoId;
  int? _fomentoProgramaId;
  String? _fomentoNivelEducativo;
  String? _fomentoSector;
  final List<File> _fotos = [];
  final List<ActividadVehiculo> _vehiculos = [];

  final _fechaCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController(text: 'MORELIA');
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _coordenadasCtrl = TextEditingController();
  final _fuenteUbicacionCtrl = TextEditingController();
  final _notaGeoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _narrativaCtrl = TextEditingController();
  final _accionesCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _personasAlcanzadasCtrl = TextEditingController(text: '1');
  final _personasParticipantesCtrl = TextEditingController(text: '0');
  final _personasDetenidasCtrl = TextEditingController(text: '0');
  final _elementosCtrl = TextEditingController();
  final _patrullasCtrl = TextEditingController();
  final _fomentoEscuelaCtrl = TextEditingController();
  final _fomentoDomicilioCtrl = TextEditingController();
  final _fomentoNinasCtrl = TextEditingController(text: '0');
  final _fomentoNinosCtrl = TextEditingController(text: '0');
  final _fomentoAdolescentesMujeresCtrl = TextEditingController(text: '0');
  final _fomentoAdolescentesHombresCtrl = TextEditingController(text: '0');
  final _fomentoDocentesHombresCtrl = TextEditingController(text: '0');
  final _fomentoDocentesMujeresCtrl = TextEditingController(text: '0');
  final _fomentoHombresCtrl = TextEditingController(text: '0');
  final _fomentoMujeresCtrl = TextEditingController(text: '0');
  final _fomentoTotalCtrl = TextEditingController(text: '0');

  final _categoriaFieldKey = GlobalKey();
  final _subcategoriaFieldKey = GlobalKey();
  final _fechaFieldKey = GlobalKey();
  final _horaFieldKey = GlobalKey();
  final _lugarFieldKey = GlobalKey();
  final _municipioFieldKey = GlobalKey();
  final _ubicacionCardKey = GlobalKey();
  final _personasAlcanzadasFieldKey = GlobalKey();
  final _personasParticipantesFieldKey = GlobalKey();
  final _personasDetenidasFieldKey = GlobalKey();
  final _fomentoCardKey = GlobalKey();
  final _vehiculosCardKey = GlobalKey();
  final _fotosCardKey = GlobalKey();

  final ImagePicker _picker = ImagePicker();
  late final LocalDraftAutosave _draft;

  @override
  void initState() {
    super.initState();
    _setNow();
    _draft =
        LocalDraftAutosave(draftId: 'actividades:create', collect: _draftValues)
          ..attachTextControllers({
            'fecha': _fechaCtrl,
            'hora': _horaCtrl,
            'lugar': _lugarCtrl,
            'municipio': _municipioCtrl,
            'lat': _latCtrl,
            'lng': _lngCtrl,
            'coordenadas': _coordenadasCtrl,
            'fuente_ubicacion': _fuenteUbicacionCtrl,
            'nota_geo': _notaGeoCtrl,
            'motivo': _motivoCtrl,
            'narrativa': _narrativaCtrl,
            'acciones': _accionesCtrl,
            'observaciones': _observacionesCtrl,
            'personas_alcanzadas': _personasAlcanzadasCtrl,
            'personas_participantes': _personasParticipantesCtrl,
            'personas_detenidas': _personasDetenidasCtrl,
            'elementos': _elementosCtrl,
            'patrullas': _patrullasCtrl,
            'fomento_escuela': _fomentoEscuelaCtrl,
            'fomento_domicilio': _fomentoDomicilioCtrl,
            'fomento_ninas': _fomentoNinasCtrl,
            'fomento_ninos': _fomentoNinosCtrl,
            'fomento_adolescentes_mujeres': _fomentoAdolescentesMujeresCtrl,
            'fomento_adolescentes_hombres': _fomentoAdolescentesHombresCtrl,
            'fomento_docentes_hombres': _fomentoDocentesHombresCtrl,
            'fomento_docentes_mujeres': _fomentoDocentesMujeresCtrl,
            'fomento_hombres': _fomentoHombresCtrl,
            'fomento_mujeres': _fomentoMujeresCtrl,
            'fomento_total': _fomentoTotalCtrl,
          });
    _loadCategorias();
    _loadUserLabel();
    unawaited(_loadCaptureTimestampAccess());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftHydrated) return;
    _draftHydrated = true;
    if (!_hydrateDraftFromArgs()) {
      unawaited(_restoreLocalDraft());
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    _fechaCtrl.dispose();
    _horaCtrl.dispose();
    _lugarCtrl.dispose();
    _municipioCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _coordenadasCtrl.dispose();
    _fuenteUbicacionCtrl.dispose();
    _notaGeoCtrl.dispose();
    _motivoCtrl.dispose();
    _narrativaCtrl.dispose();
    _accionesCtrl.dispose();
    _observacionesCtrl.dispose();
    _personasAlcanzadasCtrl.dispose();
    _personasParticipantesCtrl.dispose();
    _personasDetenidasCtrl.dispose();
    _elementosCtrl.dispose();
    _patrullasCtrl.dispose();
    _fomentoEscuelaCtrl.dispose();
    _fomentoDomicilioCtrl.dispose();
    _fomentoNinasCtrl.dispose();
    _fomentoNinosCtrl.dispose();
    _fomentoAdolescentesMujeresCtrl.dispose();
    _fomentoAdolescentesHombresCtrl.dispose();
    _fomentoDocentesHombresCtrl.dispose();
    _fomentoDocentesMujeresCtrl.dispose();
    _fomentoHombresCtrl.dispose();
    _fomentoMujeresCtrl.dispose();
    _fomentoTotalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserLabel() async {
    final name = await AuthService.getUserName();
    final email = await AuthService.getUserEmail();
    final unidadId = await AuthService.getUnidadId();
    final showVialidadesDisponibles =
        await AuthService.canFeedVialidadesUrbanasFromActivities();
    final isMotociclista = await AuthService.isMotociclistaRole();
    final isAgenteVial = await AuthService.isAgenteVial();
    final isFenix = await AuthService.isFenixRole();
    final narrativaGrupo = isMotociclista
        ? 'Aguilas Motocicletas'
        : (isAgenteVial ? 'CRP / Deltas' : null) ??
              (isFenix ? 'Fenix / Pie Tierra' : null);
    if (!mounted) return;
    setState(() {
      final cleanedName = (name ?? '').trim();
      final cleanedEmail = (email ?? '').trim();
      _userLabel = cleanedName.isNotEmpty
          ? cleanedName
          : (cleanedEmail.isNotEmpty ? cleanedEmail : 'Usuario actual');
      _actividadNarrativaGrupo = narrativaGrupo;
      _isFomentoUser = unidadId == AuthService.unidadCulturaVialId;
      _showVialidadesDisponibles = showVialidadesDisponibles;
    });
    _applyNarrativaTemplateIfPossible();
    if (showVialidadesDisponibles) {
      unawaited(_loadVialidadesDisponibles());
    }
    await _maybeSelectDefaultFomentoCategory();
  }

  Future<void> _loadCaptureTimestampAccess() async {
    final canEdit = await AuthService.canEditCaptureTimestamp();
    if (!mounted) return;
    setState(() {
      _canEditCaptureTimestamp = canEdit;
      _captureTimestampAccessLoaded = true;
      if (!canEdit) {
        _setNow();
      }
    });
  }

  void _setNow() {
    final now = DateTime.now();
    _fechaCtrl.text =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _horaCtrl.text =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadCategorias() async {
    try {
      final cats = await ActividadesService.fetchCategorias();
      if (!mounted) return;
      setState(() => _categorias = cats);
      if (_categoriaId != null && _categoriaId! > 0) {
        await _loadSubcategorias(
          _categoriaId!,
          preferredSubcategoriaId: _subcategoriaId,
        );
      } else {
        await _maybeSelectDefaultFomentoCategory();
      }
    } catch (e) {
      if (!mounted) return;
      final message = ActividadesService.cleanExceptionMessage(e);
      setState(() => _error = 'No se pudieron cargar categorías.\n$message');
    }
  }

  Future<void> _loadSubcategorias(
    int categoriaId, {
    int? preferredSubcategoriaId,
  }) async {
    final targetSubcategoriaId = preferredSubcategoriaId ?? _subcategoriaId;
    setState(() {
      _subcategorias = [];
      if (preferredSubcategoriaId == null) {
        _subcategoriaId = null;
      }
    });

    try {
      final subs = await ActividadesService.fetchSubcategorias(categoriaId);
      if (!mounted) return;
      setState(() {
        _subcategorias = subs;
        if (targetSubcategoriaId != null &&
            subs.any((item) => item.id == targetSubcategoriaId)) {
          _subcategoriaId = targetSubcategoriaId;
        } else if (subs.length == 1) {
          _subcategoriaId = subs.first.id;
        } else if (preferredSubcategoriaId == null) {
          _subcategoriaId = null;
        }
        _ensureFomentoProgramValid();
      });
      _syncFomentoTotal();
      _applyNarrativaTemplateIfPossible();
      _scheduleC5iHechoRedirectCheck();
    } catch (e) {
      if (!mounted) return;
      final message = ActividadesService.cleanExceptionMessage(e);
      setState(() => _error = 'No se pudieron cargar subcategorías.\n$message');
    }
  }

  DateTime _fechaParaDispositivosDisponibles() {
    return DateTime.tryParse(_fechaCtrl.text.trim()) ?? DateTime.now();
  }

  Future<void> _loadVialidadesDisponibles() async {
    if (!mounted) return;

    setState(() {
      _loadingVialidadesDisponibles = true;
      _vialidadesDisponiblesError = null;
    });

    try {
      final result = await VialidadesUrbanasService.fetchIndex(
        fecha: _fechaParaDispositivosDisponibles(),
      );
      final items = result.items.where((item) => item.id > 0).toList();

      if (!mounted) return;
      setState(() {
        _vialidadesDisponibles = items;
        if (_vialidadesDispositivoId != null &&
            !items.any((item) => item.id == _vialidadesDispositivoId)) {
          _vialidadesDispositivoId = null;
        }
        _loadingVialidadesDisponibles = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = ActividadesService.cleanExceptionMessage(e);
      setState(() {
        _vialidadesDisponibles = const <VialidadesUrbanasDispositivo>[];
        _vialidadesDispositivoId = null;
        _loadingVialidadesDisponibles = false;
        _vialidadesDisponiblesError =
            'No se pudieron cargar dispositivos disponibles.\n$message';
      });
    }
  }

  bool _hydrateDraftFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return false;

    if (_hydratePrefillFromArgs(args)) {
      return true;
    }

    if (args['offlineDraft'] is! Map) return false;

    final draft = Map<String, dynamic>.from(args['offlineDraft'] as Map);
    final fields = _stringMapFrom(draft['fields']);
    final files = _listMapFrom(draft['files']);

    _clientUuid = _firstNonEmpty(<String?>[
      (draft['id'] ?? '').toString(),
      fields['client_uuid'],
    ]);

    _categoriaId = int.tryParse(
      (fields['actividad_categoria_id'] ?? '').trim(),
    );
    _subcategoriaId = int.tryParse(
      (fields['actividad_subcategoria_id'] ?? '').trim(),
    );

    if (_canEditCaptureTimestamp || !_captureTimestampAccessLoaded) {
      _fechaCtrl.text = (fields['fecha'] ?? '').trim();
      _horaCtrl.text = (fields['hora'] ?? '').trim();
    }
    _lugarCtrl.text = (fields['lugar'] ?? '').trim();
    _municipioCtrl.text = (fields['municipio'] ?? '').trim();
    _latCtrl.text = (fields['lat'] ?? '').trim();
    _lngCtrl.text = (fields['lng'] ?? '').trim();
    _coordenadasCtrl.text = (fields['coordenadas_texto'] ?? '').trim();
    _fuenteUbicacionCtrl.text = (fields['fuente_ubicacion'] ?? '').trim();
    _notaGeoCtrl.text = (fields['nota_geo'] ?? '').trim();
    _motivoCtrl.text = (fields['motivo'] ?? '').trim();
    _narrativaCtrl.text = (fields['narrativa'] ?? '').trim();
    _accionesCtrl.text = (fields['acciones_realizadas'] ?? '').trim();
    _observacionesCtrl.text = (fields['observaciones'] ?? '').trim();
    _syncLastAutoNarrativaFromCurrent();
    _personasAlcanzadasCtrl.text = NormalizedIntegerInputFormatter.normalize(
      (fields['personas_alcanzadas'] ?? '1').trim(),
    );
    _personasParticipantesCtrl.text = NormalizedIntegerInputFormatter.normalize(
      (fields['personas_participantes'] ?? '0').trim(),
    );
    _personasDetenidasCtrl.text = NormalizedIntegerInputFormatter.normalize(
      (fields['personas_detenidas'] ?? '0').trim(),
    );
    _elementosCtrl.text = (fields['elementos_participantes_texto'] ?? '')
        .trim();
    _patrullasCtrl.text = (fields['patrullas_participantes_texto'] ?? '')
        .trim();
    _applyFomentoFields(fields);

    _fotos
      ..clear()
      ..addAll(_filesForDraft(files));
    _vehiculos
      ..clear()
      ..addAll(_vehiculosFromFields(fields));

    if (_latCtrl.text.trim().isNotEmpty && _lngCtrl.text.trim().isNotEmpty) {
      _locationStatus = 'Ubicacion recuperada del borrador offline.';
    } else if (_notaGeoCtrl.text.trim().isNotEmpty) {
      _locationStatus = _notaGeoCtrl.text.trim();
    }
    _syncFomentoTotal();
    return true;
  }

  bool _hydratePrefillFromArgs(Map<dynamic, dynamic> args) {
    final rawPrefill = args['actividadPrefill'] ?? args['prefill'];
    if (rawPrefill == null) return false;

    final prefill = rawPrefill is Map
        ? Map<String, dynamic>.from(rawPrefill)
        : Map<String, dynamic>.from(args);

    _categoriaId =
        _intValue(prefill['actividad_categoria_id']) ??
        _intValue(prefill['categoria_id']) ??
        _categoriaId;
    _subcategoriaId =
        _intValue(prefill['actividad_subcategoria_id']) ??
        _intValue(prefill['subcategoria_id']) ??
        _subcategoriaId;

    void setText(TextEditingController ctrl, dynamic value) {
      final text = _stringValue(value);
      if (text != null) ctrl.text = text;
    }

    setText(_lugarCtrl, prefill['lugar']);
    setText(_municipioCtrl, prefill['municipio']);
    setText(_latCtrl, prefill['lat']);
    setText(_lngCtrl, prefill['lng']);
    setText(_coordenadasCtrl, prefill['coordenadas_texto']);
    setText(_fuenteUbicacionCtrl, prefill['fuente_ubicacion']);
    setText(_notaGeoCtrl, prefill['nota_geo']);
    setText(_motivoCtrl, prefill['motivo']);
    final hadPrefillNarrativa = _stringValue(prefill['narrativa']) != null;
    setText(_narrativaCtrl, prefill['narrativa']);
    if (hadPrefillNarrativa) {
      _syncLastAutoNarrativaFromCurrent();
    }
    setText(_accionesCtrl, prefill['acciones_realizadas']);
    setText(_observacionesCtrl, prefill['observaciones']);
    setText(_personasAlcanzadasCtrl, prefill['personas_alcanzadas']);
    setText(_personasParticipantesCtrl, prefill['personas_participantes']);
    setText(_personasDetenidasCtrl, prefill['personas_detenidas']);
    setText(_elementosCtrl, prefill['elementos_participantes_texto']);
    setText(_patrullasCtrl, prefill['patrullas_participantes_texto']);

    if (_categoriaId != null && _categoriaId! > 0 && _categorias.isNotEmpty) {
      unawaited(
        _loadSubcategorias(
          _categoriaId!,
          preferredSubcategoriaId: _subcategoriaId,
        ),
      );
    }

    _syncFomentoTotal();
    return true;
  }

  Future<void> _restoreLocalDraft() async {
    final restored = await _draft.restore(_applyLocalDraft);
    if (!mounted || !restored) return;
    setState(() {});
    if (_categoriaId != null && _categoriaId! > 0) {
      await _loadSubcategorias(
        _categoriaId!,
        preferredSubcategoriaId: _subcategoriaId,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Borrador local recuperado.')));
  }

  void _applyLocalDraft(Map<String, dynamic> draft) {
    _clientUuid = _stringValue(draft['client_uuid']);
    _categoriaId = _intValue(draft['categoria_id']);
    _subcategoriaId = _intValue(draft['subcategoria_id']);

    if (_canEditCaptureTimestamp || !_captureTimestampAccessLoaded) {
      _fechaCtrl.text = _stringValue(draft['fecha']) ?? _fechaCtrl.text;
      _horaCtrl.text = _stringValue(draft['hora']) ?? _horaCtrl.text;
    }
    _lugarCtrl.text = _stringValue(draft['lugar']) ?? '';
    _municipioCtrl.text = _stringValue(draft['municipio']) ?? '';
    _latCtrl.text = _stringValue(draft['lat']) ?? '';
    _lngCtrl.text = _stringValue(draft['lng']) ?? '';
    _coordenadasCtrl.text = _stringValue(draft['coordenadas']) ?? '';
    _fuenteUbicacionCtrl.text = _stringValue(draft['fuente_ubicacion']) ?? '';
    _notaGeoCtrl.text = _stringValue(draft['nota_geo']) ?? '';
    _motivoCtrl.text = _stringValue(draft['motivo']) ?? '';
    _narrativaCtrl.text = _stringValue(draft['narrativa']) ?? '';
    _accionesCtrl.text = _stringValue(draft['acciones']) ?? '';
    _observacionesCtrl.text = _stringValue(draft['observaciones']) ?? '';
    _syncLastAutoNarrativaFromCurrent();
    _personasAlcanzadasCtrl.text = NormalizedIntegerInputFormatter.normalize(
      _stringValue(draft['personas_alcanzadas']) ?? '1',
    );
    _personasParticipantesCtrl.text = NormalizedIntegerInputFormatter.normalize(
      _stringValue(draft['personas_participantes']) ?? '0',
    );
    _personasDetenidasCtrl.text = NormalizedIntegerInputFormatter.normalize(
      _stringValue(draft['personas_detenidas']) ?? '0',
    );
    _elementosCtrl.text = _stringValue(draft['elementos']) ?? '';
    _patrullasCtrl.text = _stringValue(draft['patrullas']) ?? '';
    _applyFomentoDraft(draft['fomento']);

    _fotos
      ..clear()
      ..addAll(_filesFromPaths(draft['fotos']));
    _vehiculos
      ..clear()
      ..addAll(_actividadVehiculosFromDraft(draft['vehiculos']));

    if (_latCtrl.text.trim().isNotEmpty && _lngCtrl.text.trim().isNotEmpty) {
      _locationStatus = 'Ubicacion recuperada del borrador local.';
    } else if (_notaGeoCtrl.text.trim().isNotEmpty) {
      _locationStatus = _notaGeoCtrl.text.trim();
    }
    _syncFomentoTotal();
  }

  Map<String, dynamic> _draftValues() {
    return <String, dynamic>{
      'client_uuid': _clientUuid,
      'categoria_id': _categoriaId,
      'subcategoria_id': _subcategoriaId,
      'fecha': _fechaCtrl.text,
      'hora': _horaCtrl.text,
      'lugar': _lugarCtrl.text,
      'municipio': _municipioCtrl.text,
      'lat': _latCtrl.text,
      'lng': _lngCtrl.text,
      'coordenadas': _coordenadasCtrl.text,
      'fuente_ubicacion': _fuenteUbicacionCtrl.text,
      'nota_geo': _notaGeoCtrl.text,
      'motivo': _motivoCtrl.text,
      'narrativa': _narrativaCtrl.text,
      'acciones': _accionesCtrl.text,
      'observaciones': _observacionesCtrl.text,
      'personas_alcanzadas': _integerText(_personasAlcanzadasCtrl),
      'personas_participantes': _integerText(_personasParticipantesCtrl),
      'personas_detenidas': _integerText(_personasDetenidasCtrl),
      'elementos': _elementosCtrl.text,
      'patrullas': _patrullasCtrl.text,
      'fomento': _buildFomentoPayload().toJson(),
      'fotos': _fotos.map((file) => file.path).toList(),
      'vehiculos': _vehiculos.map((vehiculo) => vehiculo.toJson()).toList(),
    };
  }

  String? _stringValue(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString().trim());
  }

  List<File> _filesFromPaths(dynamic value) {
    if (value is! List) return const <File>[];
    return value
        .map((item) => File(item.toString()))
        .where((file) => file.existsSync())
        .toList();
  }

  List<ActividadVehiculo> _actividadVehiculosFromDraft(dynamic value) {
    if (value is! List) return const <ActividadVehiculo>[];
    return value.whereType<Map>().map((item) {
      return ActividadVehiculo.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  Map<String, String> _stringMapFrom(dynamic value) {
    if (value is! Map) return const <String, String>{};
    return value.map(
      (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
    );
  }

  List<Map<String, dynamic>> _listMapFrom(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _applyFomentoFields(Map<String, String> fields) {
    String? field(String key) =>
        _firstNonEmpty(<String?>[fields['fomento[$key]'], fields[key]]);

    _fomentoProgramaId = int.tryParse(field('programa_id') ?? '');
    _fomentoEscuelaCtrl.text =
        field('escuela') ?? field('nombre_institucion') ?? '';
    _fomentoDomicilioCtrl.text = field('domicilio') ?? '';
    _fomentoNivelEducativo = field('nivel_educativo');
    _fomentoSector = field('sector');

    void setCount(String key, TextEditingController controller) {
      controller.text = NormalizedIntegerInputFormatter.normalize(
        field(key) ?? '0',
      );
      if (controller.text.trim().isEmpty) controller.text = '0';
    }

    setCount('ninas', _fomentoNinasCtrl);
    setCount('ninos', _fomentoNinosCtrl);
    setCount('adolescentes_mujeres', _fomentoAdolescentesMujeresCtrl);
    setCount('adolescentes_hombres', _fomentoAdolescentesHombresCtrl);
    setCount('docentes_hombres', _fomentoDocentesHombresCtrl);
    setCount('docentes_mujeres', _fomentoDocentesMujeresCtrl);
    setCount('hombres', _fomentoHombresCtrl);
    setCount('mujeres', _fomentoMujeresCtrl);
  }

  void _applyFomentoDraft(dynamic raw) {
    if (raw is! Map) return;
    final data = raw.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
    _applyFomentoFields(data);
  }

  List<File> _filesForDraft(List<Map<String, dynamic>> files) {
    final restored = <File>[];
    for (final item in files) {
      final field = (item['field'] ?? '').toString().trim();
      if (field != 'fotos[]' && field != 'foto') continue;

      final path = (item['path'] ?? '').toString().trim();
      if (path.isEmpty) continue;

      final file = File(path);
      if (!file.existsSync()) continue;
      if (restored.any((existing) => existing.path == file.path)) continue;
      restored.add(file);
    }
    return restored;
  }

  List<ActividadVehiculo> _vehiculosFromFields(Map<String, String> fields) {
    final grouped = <int, Map<String, String>>{};
    final pattern = RegExp(r'^vehiculos\[(\d+)\]\[([^\]]+)\]$');

    for (final entry in fields.entries) {
      final match = pattern.firstMatch(entry.key);
      if (match == null) continue;

      final index = int.tryParse(match.group(1) ?? '');
      final field = match.group(2);
      if (index == null || field == null) continue;

      grouped.putIfAbsent(index, () => <String, String>{})[field] = entry.value;
    }

    final indexes = grouped.keys.toList()..sort();

    return indexes
        .map((index) => _vehiculoFromMap(grouped[index] ?? const {}))
        .where((vehiculo) => vehiculo.marca.trim().isNotEmpty)
        .toList();
  }

  ActividadVehiculo _vehiculoFromMap(Map<String, String> data) {
    String? str(String key) {
      final clean = (data[key] ?? '').trim();
      return clean.isEmpty ? null : clean;
    }

    bool boolValue(String key) {
      final raw = (data[key] ?? '').trim().toLowerCase();
      return raw == '1' || raw == 'true' || raw == 'si' || raw == 'sí';
    }

    return ActividadVehiculo(
      marca: str('marca') ?? '',
      modelo: str('modelo'),
      tipoGeneral: str('tipo_general'),
      tipo: str('tipo') ?? '',
      linea: str('linea') ?? '',
      color: str('color') ?? '',
      placas: str('placas'),
      estadoPlacas: str('estado_placas'),
      serie: str('serie'),
      capacidadPersonas: int.tryParse(str('capacidad_personas') ?? '') ?? 0,
      tipoServicio: VehiculoFormService.tipoServicioPlacaValue(
        str('tipo_servicio'),
      ),
      tarjetaCirculacionNombre: str('tarjeta_circulacion_nombre'),
      gruaId: int.tryParse(str('grua_id') ?? ''),
      grua: str('grua'),
      corralonId: int.tryParse(str('corralon_id') ?? ''),
      corralon: str('corralon'),
      aseguradora: str('aseguradora'),
      antecedenteVehiculo: boolValue('antecedente_vehiculo'),
      montoDanos: double.tryParse(str('monto_danos') ?? ''),
      partesDanadas: str('partes_danadas'),
    );
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final item in values) {
      final clean = (item ?? '').trim();
      if (clean.isNotEmpty) return clean;
    }
    return null;
  }

  ActividadCategoria? _selectedCategoria() {
    final id = _categoriaId;
    if (id == null) return null;
    for (final categoria in _categorias) {
      if (categoria.id == id) return categoria;
    }
    return null;
  }

  ActividadSubcategoria? _selectedSubcategoria() {
    final id = _subcategoriaId;
    if (id == null) return null;
    for (final subcategoria in _subcategorias) {
      if (subcategoria.id == id) return subcategoria;
    }
    return null;
  }

  bool get _showFomentoPanel {
    return _selectedCategoria()?.requiereFomentoCulturaVial ?? false;
  }

  bool get _useFomentoUserLayout {
    return _isFomentoUser && _showFomentoPanel;
  }

  List<ActividadFomentoPrograma> get _fomentoProgramas {
    return _selectedSubcategoria()?.programasFomento ??
        const <ActividadFomentoPrograma>[];
  }

  void _syncLastAutoNarrativaFromCurrent() {
    final current = _narrativaCtrl.text.trim();
    _lastAutoNarrativa =
        ActividadNarrativaTemplateService.looksAutoGenerated(current)
        ? current
        : null;
    _narrativaEditadaPorUsuario = false;
  }

  bool get _canReplaceNarrativaWithTemplate {
    if (_narrativaEditadaPorUsuario) return false;

    final current = _narrativaCtrl.text.trim();
    if (current.isEmpty) return true;

    final last = (_lastAutoNarrativa ?? '').trim();
    if (last.isNotEmpty && current == last) return true;

    return ActividadNarrativaTemplateService.looksAutoGenerated(current);
  }

  void _clearNarrativaTemplateIfCurrent() {
    final current = _narrativaCtrl.text.trim();
    if (current.isEmpty) {
      _lastAutoNarrativa = null;
      _narrativaEditadaPorUsuario = false;
      return;
    }
    if (!_canReplaceNarrativaWithTemplate) return;

    setState(() {
      _narrativaCtrl.clear();
      _lastAutoNarrativa = null;
      _narrativaEditadaPorUsuario = false;
    });
    _draft.notifyChanged();
  }

  void _applyNarrativaTemplateIfPossible() {
    final categoria = _selectedCategoria();
    final subcategoria = _selectedSubcategoria();

    if (categoria == null || subcategoria == null) {
      _clearNarrativaTemplateIfCurrent();
      return;
    }
    if (!_canReplaceNarrativaWithTemplate) return;

    final template = ActividadNarrativaTemplateService.build(
      categoriaNombre: categoria.nombre,
      subcategoriaNombre: subcategoria.nombre,
      lugar: _lugarCtrl.text,
      municipio: _municipioCtrl.text,
      operationalGroupLabel: _actividadNarrativaGrupo,
      requiereFomentoCulturaVial: _showFomentoPanel,
    );

    if (_narrativaCtrl.text == template) {
      _lastAutoNarrativa = template;
      return;
    }

    setState(() {
      _narrativaCtrl.text = template;
      _lastAutoNarrativa = template;
      _narrativaEditadaPorUsuario = false;
    });
    _draft.notifyChanged();
  }

  void _handleNarrativaChanged(String value) {
    final current = value.trim();
    if (current.isEmpty) {
      _lastAutoNarrativa = null;
      _narrativaEditadaPorUsuario = false;
      return;
    }

    final last = (_lastAutoNarrativa ?? '').trim();
    _narrativaEditadaPorUsuario = last.isEmpty || current != last;
    if (_narrativaEditadaPorUsuario) {
      _lastAutoNarrativa = null;
    }
  }

  Map<String, TextEditingController> get _fomentoCountControllers => {
    'ninas': _fomentoNinasCtrl,
    'ninos': _fomentoNinosCtrl,
    'adolescentes_mujeres': _fomentoAdolescentesMujeresCtrl,
    'adolescentes_hombres': _fomentoAdolescentesHombresCtrl,
    'docentes_hombres': _fomentoDocentesHombresCtrl,
    'docentes_mujeres': _fomentoDocentesMujeresCtrl,
    'hombres': _fomentoHombresCtrl,
    'mujeres': _fomentoMujeresCtrl,
  };

  int? _defaultFomentoCategoriaId(List<ActividadCategoria> categorias) {
    for (final categoria in categorias) {
      final slug = (categoria.slug ?? '').trim().toLowerCase();
      final nombre = categoria.nombre.trim().toUpperCase();
      if (slug == 'capacitaciones' || nombre == 'CAPACITACIONES') {
        return categoria.id;
      }
    }

    for (final categoria in categorias) {
      if (categoria.requiereFomentoCulturaVial) return categoria.id;
    }
    return null;
  }

  Future<void> _maybeSelectDefaultFomentoCategory() async {
    if (!mounted ||
        !_isFomentoUser ||
        _categoriaId != null ||
        _categorias.isEmpty) {
      return;
    }
    final defaultId = _defaultFomentoCategoriaId(_categorias);
    if (defaultId == null) return;

    if (!mounted) return;
    setState(() => _categoriaId = defaultId);
    _draft.notifyChanged();
    await _loadSubcategorias(defaultId);
  }

  void _ensureFomentoProgramValid() {
    if (_fomentoProgramaId == null) return;
    if (_fomentoProgramas.any(
      (programa) => programa.id == _fomentoProgramaId,
    )) {
      return;
    }
    _fomentoProgramaId = null;
  }

  int _readFomentoCount(TextEditingController controller) {
    final normalized = NormalizedIntegerInputFormatter.normalize(
      controller.text,
    );
    return (int.tryParse(normalized) ?? 0)
        .clamp(0, ActividadFomentoDetalle.maxCount)
        .toInt();
  }

  int _fomentoTotal() {
    return _fomentoCountControllers.values.fold<int>(
      0,
      (sum, controller) => sum + _readFomentoCount(controller),
    );
  }

  void _syncFomentoTotal() {
    final total = _fomentoTotal();
    final totalText = total.toString();
    if (_fomentoTotalCtrl.text != totalText) {
      _fomentoTotalCtrl.text = totalText;
    }
    if (_showFomentoPanel && _personasAlcanzadasCtrl.text != totalText) {
      _personasAlcanzadasCtrl.text = totalText;
    }
  }

  ActividadFomentoDetalle _buildFomentoPayload() {
    final total = _fomentoTotal();
    return ActividadFomentoDetalle(
      programaId: _fomentoProgramaId,
      escuela: _trim(_fomentoEscuelaCtrl),
      domicilio: _trim(_fomentoDomicilioCtrl),
      nivelEducativo: _fomentoNivelEducativo,
      sector: _fomentoSector,
      ninas: _readFomentoCount(_fomentoNinasCtrl),
      ninos: _readFomentoCount(_fomentoNinosCtrl),
      adolescentesMujeres: _readFomentoCount(_fomentoAdolescentesMujeresCtrl),
      adolescentesHombres: _readFomentoCount(_fomentoAdolescentesHombresCtrl),
      docentesHombres: _readFomentoCount(_fomentoDocentesHombresCtrl),
      docentesMujeres: _readFomentoCount(_fomentoDocentesMujeresCtrl),
      hombres: _readFomentoCount(_fomentoHombresCtrl),
      mujeres: _readFomentoCount(_fomentoMujeresCtrl),
      totalPoblacionAtendida: total,
    );
  }

  void _scheduleC5iHechoRedirectCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_redirectToHechoIfC5iReport());
    });
  }

  Future<void> _redirectToHechoIfC5iReport() async {
    if (_redirectingToHecho || !mounted) return;
    if (_isFomentoUser) return;

    final userCanCaptureHechos = await AuthService.canCreateHechos();
    if (!mounted || !userCanCaptureHechos) return;

    final categoria = _selectedCategoria();
    final subcategoria = _selectedSubcategoria();
    if (categoria == null || subcategoria == null) return;

    final shouldRedirect = ActividadesService.shouldRedirectC5iReportToHecho(
      categoriaNombre: categoria.nombre,
      subcategoriaNombre: subcategoria.nombre,
      userCanCaptureHechos: userCanCaptureHechos,
    );
    if (!shouldRedirect) return;

    _redirectingToHecho = true;
    await _draft.discard();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ese reporte C5i debe capturarse como hecho.'),
      ),
    );
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.accidentesCreate,
      arguments: {
        'prefill': {
          'source': 'actividad_c5i_redirect',
          'lugar': _lugarCtrl.text.trim(),
          'municipio': _trimMunicipio(_municipioCtrl) ?? '',
          'lat': _latCtrl.text.trim(),
          'lng': _lngCtrl.text.trim(),
          'coordenadas_texto': _coordenadasCtrl.text.trim(),
          'fuente_ubicacion': _fuenteUbicacionCtrl.text.trim(),
          'nota_geo': _notaGeoCtrl.text.trim(),
          'situacion': 'REPORTE',
        },
      },
    );
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _error = null;
      _removeFieldError(ActividadValidationTarget.fotos);
    });

    final files = await PhotoPickerService.pickAndCropMultiImage(
      context,
      _picker,
    );
    if (files.isEmpty || !mounted) return;

    setState(() {
      for (final file in files) {
        if (!_fotos.any((f) => f.path == file.path)) {
          _fotos.add(file);
        }
      }
      _removeFieldError(ActividadValidationTarget.fotos);
    });
    _draft.notifyChanged();
  }

  Future<void> _pickFromCamera() async {
    setState(() {
      _error = null;
      _removeFieldError(ActividadValidationTarget.fotos);
    });

    final file = await PhotoPickerService.pickAndCropImage(
      context,
      _picker,
      source: ImageSource.camera,
    );
    if (file == null) return;
    if (!mounted) return;

    setState(() {
      if (!_fotos.any((f) => f.path == file.path)) {
        _fotos.add(file);
      }
      _removeFieldError(ActividadValidationTarget.fotos);
    });
    _draft.notifyChanged();
  }

  Future<void> _captureLocation() async {
    if (_locating) return;

    setState(() {
      _locating = true;
      _locationStatus = 'Obteniendo ubicacion...';
      _error = null;
      _removeFieldError(ActividadValidationTarget.ubicacion);
    });

    final geo = await GeoService.getCurrent();
    if (!mounted) return;

    if (geo.lat == null || geo.lng == null) {
      setState(() {
        _locating = false;
        _locationStatus = geo.notaGeo ?? 'No se pudo obtener la ubicacion.';
      });
      return;
    }

    final lat = geo.lat!.toStringAsFixed(7);
    final lng = geo.lng!.toStringAsFixed(7);

    setState(() {
      _locating = false;
      _latCtrl.text = lat;
      _lngCtrl.text = lng;
      _coordenadasCtrl.text = '$lat, $lng';
      _fuenteUbicacionCtrl.text = geo.fuenteUbicacion ?? 'GPS_APP';
      _notaGeoCtrl.text = geo.notaGeo ?? '';
      _locationStatus = geo.captureSummary;
      _removeFieldError(ActividadValidationTarget.ubicacion);
    });
    _draft.notifyChanged();
  }

  String? _fieldError(ActividadValidationTarget target) {
    return _fieldErrors[target];
  }

  String? _fieldErrorForTargets(Iterable<ActividadValidationTarget> targets) {
    final messages = <String>[];
    for (final target in targets) {
      final message = _fieldErrors[target];
      if (message != null && !messages.contains(message)) {
        messages.add(message);
      }
    }
    return messages.isEmpty ? null : messages.join('\n');
  }

  void _removeFieldError(ActividadValidationTarget target) {
    if (!_fieldErrors.containsKey(target)) return;
    _fieldErrors = Map<ActividadValidationTarget, String>.from(_fieldErrors)
      ..remove(target);
    if (_fieldErrors.isEmpty) _error = null;
  }

  void _clearFieldError(ActividadValidationTarget target) {
    if (!_fieldErrors.containsKey(target)) return;
    setState(() => _removeFieldError(target));
  }

  void _clearValidationErrors() {
    _fieldErrors = {};
    _error = null;
  }

  Map<ActividadValidationTarget, String> _groupValidationIssues(
    List<ActividadValidationIssue> issues,
  ) {
    final grouped = <ActividadValidationTarget, List<String>>{};
    for (final issue in issues) {
      grouped.putIfAbsent(issue.target, () => <String>[]).add(issue.message);
    }
    return grouped.map(
      (target, messages) => MapEntry(target, messages.join('\n')),
    );
  }

  GlobalKey? _keyForValidationTarget(ActividadValidationTarget target) {
    switch (target) {
      case ActividadValidationTarget.categoria:
        return _categoriaFieldKey;
      case ActividadValidationTarget.subcategoria:
        return _subcategoriaFieldKey;
      case ActividadValidationTarget.fecha:
        return _fechaFieldKey;
      case ActividadValidationTarget.hora:
        return _horaFieldKey;
      case ActividadValidationTarget.lugar:
        return _lugarFieldKey;
      case ActividadValidationTarget.municipio:
        return _municipioFieldKey;
      case ActividadValidationTarget.ubicacion:
      case ActividadValidationTarget.fuenteUbicacion:
      case ActividadValidationTarget.notaGeo:
      case ActividadValidationTarget.carretera:
      case ActividadValidationTarget.tramo:
      case ActividadValidationTarget.kilometro:
        return _ubicacionCardKey;
      case ActividadValidationTarget.personasAlcanzadas:
        return _personasAlcanzadasFieldKey;
      case ActividadValidationTarget.personasParticipantes:
        return _personasParticipantesFieldKey;
      case ActividadValidationTarget.personasDetenidas:
        return _personasDetenidasFieldKey;
      case ActividadValidationTarget.fomento:
        return _fomentoCardKey;
      case ActividadValidationTarget.fotos:
        return _fotosCardKey;
      case ActividadValidationTarget.vehiculos:
        return _vehiculosCardKey;
    }
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    final targetContext = key.currentContext;
    if (targetContext == null || !targetContext.mounted) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  Future<void> _showValidationIssues(
    List<ActividadValidationIssue> issues,
  ) async {
    setState(() {
      _fieldErrors = _groupValidationIssues(issues);
      _error = ActividadesService.formatValidationIssues(issues);
    });

    final targetKey = _keyForValidationTarget(issues.first.target);
    if (targetKey != null) {
      await _scrollToKey(targetKey);
    }
  }

  String? _trim(TextEditingController ctrl) {
    final value = ctrl.text.trim();
    return value.isEmpty ? null : value;
  }

  String? _trimMunicipio(TextEditingController ctrl) {
    final canonical = MunicipiosMichoacan.canonical(ctrl.text);
    return canonical ?? _trim(ctrl);
  }

  String? _trimInteger(TextEditingController ctrl) {
    final value = _integerText(ctrl);
    return value.isEmpty ? null : value;
  }

  String _integerText(TextEditingController ctrl) {
    return NormalizedIntegerInputFormatter.normalize(ctrl.text.trim());
  }

  ActividadUpsertData _buildPayload() {
    final fomento = _showFomentoPanel ? _buildFomentoPayload() : null;
    return ActividadUpsertData(
      clientUuid: _clientUuid,
      actividadCategoriaId: _categoriaId ?? 0,
      actividadSubcategoriaId: _subcategoriaId,
      fecha: _canEditCaptureTimestamp ? _trim(_fechaCtrl) : null,
      hora: _canEditCaptureTimestamp ? _trim(_horaCtrl) : null,
      lugar: _trim(_lugarCtrl),
      municipio: _trimMunicipio(_municipioCtrl),
      lat: _trim(_latCtrl),
      lng: _trim(_lngCtrl),
      coordenadasTexto: _trim(_coordenadasCtrl),
      fuenteUbicacion: _trim(_fuenteUbicacionCtrl),
      notaGeo: _trim(_notaGeoCtrl),
      motivo: _useFomentoUserLayout ? null : _trim(_motivoCtrl),
      narrativa: _trim(_narrativaCtrl),
      accionesRealizadas: null,
      observaciones: _trim(_observacionesCtrl),
      personasAlcanzadas: fomento == null
          ? _trimInteger(_personasAlcanzadasCtrl)
          : fomento.computedTotal.toString(),
      personasParticipantes: _trimInteger(_personasParticipantesCtrl),
      personasDetenidas: _trimInteger(_personasDetenidasCtrl),
      elementosParticipantesTexto: _trim(_elementosCtrl),
      patrullasParticipantesTexto: _trim(_patrullasCtrl),
      fomento: fomento,
      vehiculos: _useFomentoUserLayout
          ? const <ActividadVehiculo>[]
          : List<ActividadVehiculo>.from(_vehiculos),
    );
  }

  Future<void> _agregarVehiculo() async {
    final vehiculo = await showActividadVehiculoModal(context);
    if (vehiculo == null || !mounted) return;

    setState(() {
      _vehiculos.add(vehiculo);
      _removeFieldError(ActividadValidationTarget.vehiculos);
    });
    _draft.notifyChanged();
  }

  void _quitarVehiculo(int index) {
    setState(() => _vehiculos.removeAt(index));
    _draft.notifyChanged();
  }

  VialidadesUrbanasDispositivo? _selectedVialidadesDispositivo() {
    final id = _vialidadesDispositivoId;
    if (id == null) return null;
    for (final item in _vialidadesDisponibles) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _openVialidadesDetalle({required bool capturar}) async {
    final item = _selectedVialidadesDispositivo();
    if (item == null) return;

    final route = capturar
        ? AppRoutes.vialidadesUrbanasDispositivoCreate
        : AppRoutes.vialidadesUrbanasDispositivoShow;
    await Navigator.pushNamed(
      context,
      route,
      arguments: <String, dynamic>{'dispositivoId': item.id},
    );
    if (!mounted) return;
    await _loadVialidadesDisponibles();
  }

  Future<void> _submit() async {
    setState(_clearValidationErrors);

    final payload = _buildPayload();
    final validationIssues =
        await ActividadesService.validateBeforeSubmitIssues(
          data: payload,
          fotos: List<File>.from(_fotos),
          requireTimestamp: _canEditCaptureTimestamp,
        );
    if (!mounted) return;
    if (validationIssues.isNotEmpty) {
      await _showValidationIssues(validationIssues);
      return;
    }

    if (!mounted) return;
    final confirmedCounts = await ActividadPeopleCountGuard.confirmIfNeeded(
      context,
      payload,
    );
    if (!confirmedCounts || !mounted) return;

    if (_saving) return;
    setState(() => _saving = true);

    try {
      final result = await ActividadesService.create(
        data: payload,
        fotos: List<File>.from(_fotos),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      await _draft.discard();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = {};
        _error =
            'No se pudo crear.\n${ActividadesService.cleanExceptionMessage(e)}';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(
    String label, {
    String? hint,
    ActividadValidationTarget? validationTarget,
  }) {
    final errorText = validationTarget == null
        ? null
        : _fieldError(validationTarget);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      errorMaxLines: 4,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 3),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    ActividadValidationTarget? validationTarget,
    Key? fieldKey,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      onChanged: (value) {
        if (validationTarget != null) {
          _clearFieldError(validationTarget);
        }
        onChanged?.call(value);
      },
      decoration: _dec(label, hint: hint, validationTarget: validationTarget),
    );
  }

  Widget _previewFotos() {
    if (_fotos.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'Sin fotos',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _fotos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final foto = _fotos[index];
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(foto, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: InkWell(
                onTap: _saving
                    ? null
                    : () {
                        setState(() {
                          _fotos.removeAt(index);
                          if (_fotos.isNotEmpty) {
                            _removeFieldError(ActividadValidationTarget.fotos);
                          }
                        });
                        _draft.notifyChanged();
                      },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _shortDispositivoHour(String raw) {
    final match = RegExp(
      r'([01]?\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?',
    ).firstMatch(raw);
    if (match == null) return raw.trim();
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
  }

  String _vialidadesDispositivoLabel(VialidadesUrbanasDispositivo item) {
    final title = item.asunto.trim().isNotEmpty
        ? item.asunto.trim()
        : item.catalogoNombre.trim();
    final parts = <String>[
      '#${item.id}',
      if (title.isNotEmpty) title,
      if (item.hora.trim().isNotEmpty) _shortDispositivoHour(item.hora),
    ];
    return parts.join(' • ');
  }

  Widget _dispositivosDisponiblesCard() {
    final ids = _vialidadesDisponibles.map((item) => item.id).toSet();
    final safeValue = ids.contains(_vialidadesDispositivoId)
        ? _vialidadesDispositivoId
        : null;
    final selected = _selectedVialidadesDispositivo();

    return _card(
      title: 'Dispositivos disponibles',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingVialidadesDisponibles)
            const Center(child: CircularProgressIndicator())
          else if (_vialidadesDisponiblesError != null)
            Text(
              _vialidadesDisponiblesError!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (_vialidadesDisponibles.isEmpty)
            const Text('Sin dispositivos disponibles para la fecha.')
          else ...[
            DropdownButtonFormField<int>(
              value: safeValue,
              isExpanded: true,
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('Seleccione dispositivo...'),
                ),
                ..._vialidadesDisponibles.map(
                  (item) => DropdownMenuItem<int>(
                    value: item.id,
                    child: Text(
                      _vialidadesDispositivoLabel(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() => _vialidadesDispositivoId = value);
                    },
              decoration: _dec('Dispositivo'),
            ),
            if (selected != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(text: selected.catalogoNombre),
                  if (selected.lugar.trim().isNotEmpty)
                    _Pill(text: selected.lugar.trim()),
                  if (selected.hora.trim().isNotEmpty)
                    _Pill(text: _shortDispositivoHour(selected.hora)),
                  _Pill(text: '${selected.detallesCount} detalles'),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: selected == null
                        ? null
                        : () => _openVialidadesDetalle(capturar: false),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver detalle'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: selected == null
                        ? null
                        : () => _openVialidadesDetalle(capturar: true),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Capturar detalle'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadingVialidadesDisponibles
                  ? null
                  : _loadVialidadesDisponibles,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords =
        _latCtrl.text.trim().isNotEmpty && _lngCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Crear actividad'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withValues(alpha: .2)),
                ),
                child: Text(_error!),
              ),
            if (_error != null) const SizedBox(height: 12),

            if (_showVialidadesDisponibles) ...[
              _dispositivosDisponiblesCard(),
              const SizedBox(height: 12),
            ],

            _card(
              title: 'Datos generales',
              child: Column(
                children: [
                  _textField(
                    TextEditingController(text: _userLabel ?? 'Usuario actual'),
                    'Nombre',
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Se toma automaticamente del usuario. No se puede editar.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: _categoriaFieldKey,
                    value: _categoriaId,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Seleccione categoria...'),
                      ),
                      ..._categorias.map(
                        (c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.nombre),
                        ),
                      ),
                    ],
                    onChanged: (v) async {
                      setState(() {
                        _categoriaId = v;
                        _subcategoriaId = null;
                        _fomentoProgramaId = null;
                        _subcategorias = [];
                        _removeFieldError(ActividadValidationTarget.categoria);
                        _removeFieldError(
                          ActividadValidationTarget.subcategoria,
                        );
                      });
                      _syncFomentoTotal();
                      if (v == null) {
                        _clearNarrativaTemplateIfCurrent();
                      }
                      _draft.notifyChanged();
                      if (v != null) {
                        await _loadSubcategorias(v);
                      }
                    },
                    decoration: _dec(
                      'Categoria',
                      validationTarget: ActividadValidationTarget.categoria,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: _subcategoriaFieldKey,
                    value: _subcategoriaId,
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          _subcategorias.isEmpty
                              ? 'No hay subcategorias disponibles'
                              : 'Seleccione subcategoria...',
                        ),
                      ),
                      ..._subcategorias.map(
                        (s) => DropdownMenuItem<int>(
                          value: s.id,
                          child: Text(s.nombre),
                        ),
                      ),
                    ],
                    onChanged: _subcategorias.isEmpty
                        ? null
                        : (v) {
                            setState(() {
                              _subcategoriaId = v;
                              _fomentoProgramaId = null;
                              _removeFieldError(
                                ActividadValidationTarget.subcategoria,
                              );
                            });
                            _syncFomentoTotal();
                            if (v == null) {
                              _clearNarrativaTemplateIfCurrent();
                            } else {
                              _applyNarrativaTemplateIfPossible();
                            }
                            _draft.notifyChanged();
                            _scheduleC5iHechoRedirectCheck();
                          },
                    decoration: _dec(
                      'Subcategoria',
                      validationTarget: ActividadValidationTarget.subcategoria,
                    ),
                  ),
                  if (_categoriaId != null && _subcategorias.isEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No puedes guardar la actividad hasta que esa categoria tenga subcategorias en el servidor.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              title: 'Fecha, hora y lugar',
              child: Column(
                children: [
                  if (_canEditCaptureTimestamp) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _textField(
                            _fechaCtrl,
                            'Fecha',
                            hint: 'YYYY-MM-DD',
                            validationTarget: ActividadValidationTarget.fecha,
                            fieldKey: _fechaFieldKey,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _textField(
                            _horaCtrl,
                            'Hora',
                            hint: 'HH:mm',
                            validationTarget: ActividadValidationTarget.hora,
                            fieldKey: _horaFieldKey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() {
                                  _setNow();
                                  _removeFieldError(
                                    ActividadValidationTarget.fecha,
                                  );
                                  _removeFieldError(
                                    ActividadValidationTarget.hora,
                                  );
                                });
                                _draft.notifyChanged();
                              },
                        icon: const Icon(Icons.access_time),
                        label: const Text('Usar fecha y hora actual'),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        'Fecha y hora se fijan con el reloj del servidor al guardar.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _textField(
                    _lugarCtrl,
                    'Lugar',
                    validationTarget: ActividadValidationTarget.lugar,
                    fieldKey: _lugarFieldKey,
                    onChanged: (_) => _applyNarrativaTemplateIfPossible(),
                  ),
                  const SizedBox(height: 12),
                  MunicipioAutocompleteField(
                    key: _municipioFieldKey,
                    controller: _municipioCtrl,
                    decoration: _dec(
                      'Municipio',
                      validationTarget: ActividadValidationTarget.municipio,
                    ),
                    enabled: !_saving,
                    onChanged: (_) {
                      _clearFieldError(ActividadValidationTarget.municipio);
                      _applyNarrativaTemplateIfPossible();
                      _draft.notifyChanged();
                    },
                    onSelected: (_) {
                      _clearFieldError(ActividadValidationTarget.municipio);
                      _applyNarrativaTemplateIfPossible();
                      _draft.notifyChanged();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              title: 'Ubicacion',
              cardKey: _ubicacionCardKey,
              validationTargets: const <ActividadValidationTarget>[
                ActividadValidationTarget.ubicacion,
                ActividadValidationTarget.fuenteUbicacion,
                ActividadValidationTarget.notaGeo,
                ActividadValidationTarget.carretera,
                ActividadValidationTarget.tramo,
                ActividadValidationTarget.kilometro,
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: (_saving || _locating)
                            ? null
                            : _captureLocation,
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          _locating ? 'Obteniendo...' : 'Usar mi ubicacion',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _locationStatus,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  if (hasCoords) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(_coordenadasCtrl.text),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (_showFomentoPanel) ...[
              _card(
                title: 'Fomento a la Cultura Vial',
                cardKey: _fomentoCardKey,
                validationTarget: ActividadValidationTarget.fomento,
                child: FomentoCulturaVialPanel(
                  programas: _fomentoProgramas,
                  programaId: _fomentoProgramaId,
                  onProgramaChanged: (value) {
                    setState(() => _fomentoProgramaId = value);
                    _draft.notifyChanged();
                  },
                  escuelaController: _fomentoEscuelaCtrl,
                  domicilioController: _fomentoDomicilioCtrl,
                  onTextChanged: (_) => _draft.notifyChanged(),
                  nivelEducativo: _fomentoNivelEducativo,
                  onNivelEducativoChanged: (value) {
                    setState(() => _fomentoNivelEducativo = value);
                    _draft.notifyChanged();
                  },
                  sector: _fomentoSector,
                  onSectorChanged: (value) {
                    setState(() => _fomentoSector = value);
                    _draft.notifyChanged();
                  },
                  countControllers: _fomentoCountControllers,
                  totalController: _fomentoTotalCtrl,
                  onCountChanged: (_) {
                    _syncFomentoTotal();
                    _clearFieldError(ActividadValidationTarget.fomento);
                    _draft.notifyChanged();
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            _card(
              title: 'Contenido',
              child: Column(
                children: [
                  if (!_useFomentoUserLayout) ...[
                    _textField(_motivoCtrl, 'Asunto', maxLines: 2),
                    const SizedBox(height: 12),
                  ],
                  _textField(
                    _narrativaCtrl,
                    'Narrativa',
                    maxLines: 6,
                    onChanged: _handleNarrativaChanged,
                  ),
                  if (_useFomentoUserLayout) ...[
                    const SizedBox(height: 12),
                    _textField(
                      _observacionesCtrl,
                      'Observaciones',
                      maxLines: 3,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              title: 'Personas y participantes',
              child: Column(
                children: [
                  if (!_useFomentoUserLayout)
                    Row(
                      children: [
                        Expanded(
                          child: KeyedSubtree(
                            key: _personasAlcanzadasFieldKey,
                            child: ActividadCountField(
                              controller: _personasAlcanzadasCtrl,
                              label: 'Personas alcanzadas *',
                              icon: Icons.diversity_3_rounded,
                              color: const Color(0xFF0284C7),
                              helperText: _showFomentoPanel
                                  ? 'Se actualiza con el total de Fomento'
                                  : 'Minimo 1',
                              errorText: _fieldError(
                                ActividadValidationTarget.personasAlcanzadas,
                              ),
                              onChanged: (_) => _clearFieldError(
                                ActividadValidationTarget.personasAlcanzadas,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: KeyedSubtree(
                            key: _personasParticipantesFieldKey,
                            child: ActividadCountField(
                              controller: _personasParticipantesCtrl,
                              label: 'Personas participantes',
                              icon: Icons.groups_2_rounded,
                              color: const Color(0xFF7C3AED),
                              helperText: 'Maximo 15 por actividad',
                              badgeText: 'MAX 15',
                              max: ActividadesService.maxParticipantsCount,
                              errorText: _fieldError(
                                ActividadValidationTarget.personasParticipantes,
                              ),
                              onChanged: (_) => _clearFieldError(
                                ActividadValidationTarget.personasParticipantes,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: KeyedSubtree(
                            key: _personasParticipantesFieldKey,
                            child: ActividadCountField(
                              controller: _personasParticipantesCtrl,
                              label: 'Personas participantes',
                              icon: Icons.groups_2_rounded,
                              color: const Color(0xFF7C3AED),
                              helperText: 'Maximo 15 por actividad',
                              badgeText: 'MAX 15',
                              max: ActividadesService.maxParticipantsCount,
                              errorText: _fieldError(
                                ActividadValidationTarget.personasParticipantes,
                              ),
                              onChanged: (_) => _clearFieldError(
                                ActividadValidationTarget.personasParticipantes,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: KeyedSubtree(
                            key: _personasDetenidasFieldKey,
                            child: ActividadDetenidosField(
                              controller: _personasDetenidasCtrl,
                              errorText: _fieldError(
                                ActividadValidationTarget.personasDetenidas,
                              ),
                              onChanged: (_) => _clearFieldError(
                                ActividadValidationTarget.personasDetenidas,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!_useFomentoUserLayout) ...[
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: _personasDetenidasFieldKey,
                      child: ActividadDetenidosField(
                        controller: _personasDetenidasCtrl,
                        errorText: _fieldError(
                          ActividadValidationTarget.personasDetenidas,
                        ),
                        onChanged: (_) => _clearFieldError(
                          ActividadValidationTarget.personasDetenidas,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _textField(
                    _elementosCtrl,
                    'Elementos participantes',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _patrullasCtrl,
                    'Patrullas participantes',
                    maxLines: 3,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (!_useFomentoUserLayout) ...[
              _card(
                title: 'Vehiculos relacionados',
                cardKey: _vehiculosCardKey,
                validationTarget: ActividadValidationTarget.vehiculos,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total: ${_vehiculos.length}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _agregarVehiculo,
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar vehiculo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_vehiculos.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: .16),
                          ),
                        ),
                        child: const Text(
                          'No hay vehiculos agregados para esta actividad.',
                        ),
                      )
                    else
                      ..._vehiculos.asMap().entries.map((entry) {
                        return ActividadVehiculoCard(
                          vehiculo: entry.value,
                          onRemove: _saving
                              ? null
                              : () => _quitarVehiculo(entry.key),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            _card(
              title: 'Fotos',
              cardKey: _fotosCardKey,
              validationTarget: ActividadValidationTarget.fotos,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_fotos.length} archivo(s) seleccionado(s)',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 10),
                  _previewFotos(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _pickFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galeria'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _pickFromCamera,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camara'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required Widget child,
    Key? cardKey,
    ActividadValidationTarget? validationTarget,
    List<ActividadValidationTarget>? validationTargets,
  }) {
    final targets =
        validationTargets ??
        (validationTarget == null
            ? const <ActividadValidationTarget>[]
            : <ActividadValidationTarget>[validationTarget]);
    final errorText = _fieldErrorForTargets(targets);
    final hasError = errorText != null;
    return Container(
      key: cardKey,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError ? Colors.red : Colors.grey.shade200,
          width: hasError ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: .06),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            child,
            if (hasError) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorText,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

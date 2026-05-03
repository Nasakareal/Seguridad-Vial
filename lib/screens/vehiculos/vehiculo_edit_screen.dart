import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import '../../core/vehiculos/vehiculo_taxonomia.dart';
import '../../core/vehiculos/aseguradoras_vehiculo.dart';
import '../../core/vehiculos/colores_vehiculo.dart';
import '../../core/vehiculos/estados_republica.dart';
import '../../services/gruas_catalog_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/vehiculo_form_service.dart';

class VehiculoEditScreen extends StatefulWidget {
  const VehiculoEditScreen({super.key});

  @override
  State<VehiculoEditScreen> createState() => _VehiculoEditScreenState();
}

class _VehiculoEditScreenState extends State<VehiculoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();

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

  int? _gruaIdPendiente;
  int? _corralonGruaIdPendiente;

  String? _gruaNombreCargado;
  String? _corralonNombreCargado;

  static const String _baseApi = 'https://seguridadvial-mich.com/api';
  int _hechoId = 0;
  int _vehiculoId = 0;
  bool _argsOk = false;
  bool _inicializo = false;
  List<Map<String, dynamic>> _vehiculosSnapshot = const [];

  String? _tipoGeneralSeleccionado;
  String? _tipoCarroceriaSeleccionada;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inicializo) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _hechoId = int.tryParse((args['hechoId'] ?? '0').toString()) ?? 0;
      _vehiculoId = int.tryParse((args['vehiculoId'] ?? '0').toString()) ?? 0;
      if (args['vehiculosSnapshot'] is List) {
        _vehiculosSnapshot = (args['vehiculosSnapshot'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    _argsOk = _hechoId > 0 && _vehiculoId > 0;
    _inicializo = true;

    if (_argsOk) {
      _init();
    } else {
      setState(() {
        _loading = false;
        _cargandoGruas = false;
      });
    }
  }

  @override
  void dispose() {
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

  String _limpiaPlacas(String s) => VehiculoFormService.normalizePlacas(s);

  String? _tipoGeneralValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Requerido';
    return null;
  }

  String? _tipoCarroceriaValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Requerido';
    return null;
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sin token. Inicia sesión otra vez.');
    }

    final h = <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };

    if (json) h['Content-Type'] = 'application/json';
    return h;
  }

  String _decodeBody(http.Response res) {
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return res.body;
    }
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

  String _errorsToText(dynamic errors) {
    if (errors is Map) {
      final sb = StringBuffer();
      for (final entry in errors.entries) {
        final key = entry.key.toString();
        final val = entry.value;
        if (val is List) {
          for (final m in val) {
            final msg = m?.toString().trim() ?? '';
            if (msg.isNotEmpty) sb.writeln('• $key: $msg');
          }
        } else {
          final msg = val?.toString().trim() ?? '';
          if (msg.isNotEmpty) sb.writeln('• $key: $msg');
        }
      }
      final out = sb.toString().trim();
      return out.isEmpty ? '' : out;
    }
    if (errors is List) {
      final msgs = errors
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (msgs.isEmpty) return '';
      return msgs.map((m) => '• $m').join('\n');
    }
    final s = errors?.toString().trim() ?? '';
    return s.isEmpty ? '' : '• $s';
  }

  String _apiErrorText(http.Response res, {String? fallbackTitle}) {
    final body = _decodeBody(res);
    final map = _tryJsonMap(body);

    final status = res.statusCode;
    final title = (fallbackTitle ?? 'No se pudo completar la acción').trim();

    if (map != null) {
      final msg = (map['message'] ?? '').toString().trim();
      final errors = _errorsToText(map['errors']);

      if (errors.isNotEmpty) {
        final head = msg.isNotEmpty ? msg : title;
        return '$head\n\n$errors';
      }

      if (msg.isNotEmpty) return msg;
      return '$title (HTTP $status)';
    }

    final cleaned = body.trim();
    if (cleaned.isEmpty) return '$title (HTTP $status)';
    if (cleaned.startsWith('<!doctype') || cleaned.startsWith('<html')) {
      return '$title (HTTP $status)';
    }
    if (cleaned.length > 600) return '$title (HTTP $status)';
    return '$title (HTTP $status)\n\n$cleaned';
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

  List<String> _carroceriasDeTipoGeneral(String? tipoGeneral) {
    return VehiculoTaxonomia.carroceriasDeTipoGeneral(tipoGeneral);
  }

  String? _inferirTipoGeneralPorCarroceria(String? carroceria) {
    final c = (carroceria ?? '').trim();
    if (c.isEmpty) return null;

    for (final entry in VehiculoTaxonomia.carrocerias.entries) {
      for (final opt in entry.value) {
        if (opt.toUpperCase() == c.toUpperCase()) return entry.key;
      }
    }
    return null;
  }

  String? _canonFromList(String? value, List<String> options) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    for (final o in options) {
      if (o.toUpperCase() == v.toUpperCase()) return o;
    }
    return null;
  }

  String? _canonCarroceria(String? tipoGeneral, String? carroceria) {
    final opts = _carroceriasDeTipoGeneral(tipoGeneral);
    return _canonFromList(carroceria, opts);
  }

  String _normalizaNombreCatalogo(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '';

    return text
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('À', 'A')
        .replaceAll('Ä', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('É', 'E')
        .replaceAll('È', 'E')
        .replaceAll('Ë', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ì', 'I')
        .replaceAll('Ï', 'I')
        .replaceAll('Î', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ò', 'O')
        .replaceAll('Ö', 'O')
        .replaceAll('Ô', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ù', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Û', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _textoCatalogoDesde(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;

    final normalized = _normalizaNombreCatalogo(text);
    if (normalized.isEmpty ||
        normalized == 'NULL' ||
        normalized == 'NA' ||
        normalized == 'N A' ||
        normalized == 'NO' ||
        normalized == 'NINGUNO' ||
        normalized == 'NO APLICA' ||
        normalized == 'SIN GRUA' ||
        normalized == 'SIN CORRALON') {
      return null;
    }

    return text;
  }

  dynamic _valorEnRuta(dynamic source, List<String> path) {
    dynamic current = source;
    for (final segment in path) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
        continue;
      }
      return null;
    }
    return current;
  }

  String? _primerTextoEnRutas(
    Map<String, dynamic> source,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      final value = _textoCatalogoDesde(_valorEnRuta(source, path));
      if (value != null) return value;
    }
    return null;
  }

  int? _primerEnteroEnRutas(
    Map<String, dynamic> source,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      final raw = _valorEnRuta(source, path);
      if (raw == null) continue;
      if (raw is int && raw > 0) return raw;

      final value = int.tryParse(raw.toString().trim());
      if (value != null && value > 0) return value;
    }
    return null;
  }

  bool _gruaIdExisteEnLista(int? id) {
    if (id == null) return false;
    for (final g in _gruas) {
      final gid = int.tryParse((g['id'] ?? '').toString());
      if (gid == id) return true;
    }
    return false;
  }

  int? _idGruaPorNombre(String? nombre) {
    final n = _normalizaNombreCatalogo(nombre);
    if (n.isEmpty) return null;
    for (final g in _gruas) {
      final gid = int.tryParse((g['id'] ?? '').toString());
      final nom = _normalizaNombreCatalogo((g['nombre'] ?? '').toString());
      if (gid != null && nom.isNotEmpty && nom == n) {
        return gid;
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

  void _aplicarPendientesSiSePuede() {
    if (_cargandoGruas) return;

    if (_gruaIdPendiente != null && _gruaIdExisteEnLista(_gruaIdPendiente)) {
      _gruaIdSeleccionada = _gruaIdPendiente;
      _gruaIdPendiente = null;
    }

    if (_corralonGruaIdPendiente != null &&
        _gruaIdExisteEnLista(_corralonGruaIdPendiente)) {
      _corralonGruaIdSeleccionada = _corralonGruaIdPendiente;
      _corralonGruaIdPendiente = null;
    }
  }

  String? _canonEstadoValueFromApi(String? apiValue) {
    return EstadosRepublica.valueFromAny(apiValue);
  }

  Future<void> _init() async {
    try {
      await Future.wait([_cargarGruas(), _cargarVehiculo()]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _cargandoGruas = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error inicializando: $e')));
    }
  }

  Future<void> _cargarGruas() async {
    try {
      final gruas = await GruasCatalogService.fetchVisibleGruas();
      if (!mounted) return;
      setState(() {
        _gruas = gruas;
        _cargandoGruas = false;

        _aplicarPendientesSiSePuede();

        if (_gruaIdSeleccionada == null) {
          final gruaIdByNombre = _idGruaPorNombre(_gruaNombreCargado);
          if (gruaIdByNombre != null) {
            _gruaIdSeleccionada = gruaIdByNombre;
            _gruaIdPendiente = null;
          }
        }

        if (_corralonGruaIdSeleccionada == null) {
          final corralonIdByNombre = _idGruaPorNombre(_corralonNombreCargado);
          if (corralonIdByNombre != null) {
            _corralonGruaIdSeleccionada = corralonIdByNombre;
            _corralonGruaIdPendiente = null;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoGruas = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar grúas: $e')),
      );
    }
  }

  Future<void> _cargarVehiculo() async {
    setState(() => _loading = true);

    final h = await _headers();
    final uri = Uri.parse('$_baseApi/hechos/$_hechoId/vehiculos/$_vehiculoId');
    final res = await http.get(uri, headers: h);

    if (res.statusCode != 200) {
      final msg = _apiErrorText(
        res,
        fallbackTitle: 'No se pudo cargar el vehículo',
      );
      if (!mounted) return;
      setState(() => _loading = false);
      throw Exception(msg);
    }

    final raw = jsonDecode(_decodeBody(res));
    Map<String, dynamic> data;

    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      data = Map<String, dynamic>.from(raw['data'] as Map);
    } else if (raw is Map<String, dynamic>) {
      data = raw;
    } else {
      data = {};
    }

    _marcaCtrl.text = (data['marca'] ?? '').toString();
    _modeloCtrl.text = (data['modelo'] ?? '').toString();
    _lineaCtrl.text = (data['linea'] ?? '').toString();
    _colorCtrl.text = (data['color'] ?? '').toString();
    _placasCtrl.text = (data['placas'] ?? '').toString();
    _serieCtrl.text = (data['serie'] ?? '').toString();
    _capacidadCtrl.text = (data['capacidad_personas'] ?? '5').toString();
    _tipoServicioCtrl.text = (data['tipo_servicio'] ?? 'PARTICULAR').toString();
    _tarjetaCirculacionNombreCtrl.text =
        (data['tarjeta_circulacion_nombre'] ?? '').toString();
    _aseguradoraCtrl.text =
        AseguradorasVehiculo.valueFromAny(
          (data['aseguradora'] ?? '').toString(),
        ) ??
        '';
    _montoDanosCtrl.text = (data['monto_danos'] ?? '').toString();
    _partesDanadasCtrl.text = (data['partes_danadas'] ?? '').toString();
    _antecedenteVehiculo = (data['antecedente_vehiculo'] == true);

    final tipoGeneralApi = (data['tipo_general'] ?? '').toString().trim();
    final carroceriaApiRaw = (data['tipo'] ?? '').toString().trim();
    final carroceriaApi = VehiculoTaxonomia.normalizeCarroceria(
      carroceriaApiRaw,
    );

    final tipoGeneralTmp =
        (tipoGeneralApi.isNotEmpty &&
            VehiculoTaxonomia.carrocerias.containsKey(tipoGeneralApi))
        ? tipoGeneralApi
        : _inferirTipoGeneralPorCarroceria(carroceriaApi);

    _tipoGeneralSeleccionado = tipoGeneralTmp;
    _tipoCarroceriaSeleccionada = _canonCarroceria(
      _tipoGeneralSeleccionado,
      carroceriaApi,
    );

    final placasClean = _limpiaPlacas((data['placas'] ?? '').toString());
    final estadoApi = (data['estado_placas'] ?? '').toString();
    _estadoPlacasSeleccionado = placasClean.isEmpty
        ? null
        : _canonEstadoValueFromApi(estadoApi);

    final gruaIdApi = _primerEnteroEnRutas(data, [
      ['grua_id'],
      ['gruaId'],
      ['servicio', 'grua_id'],
      ['grua', 'id'],
      ['servicio', 'grua', 'id'],
    ]);
    _gruaNombreCargado = _primerTextoEnRutas(data, [
      ['grua_nombre'],
      ['grua'],
      ['servicio', 'grua_nombre'],
      ['grua', 'nombre'],
      ['servicio', 'grua', 'nombre'],
    ]);
    final gruaIdByNombre = _idGruaPorNombre(_gruaNombreCargado);

    _gruaIdSeleccionada = null;
    _gruaIdPendiente = null;

    if (gruaIdApi != null) {
      if (_gruaIdExisteEnLista(gruaIdApi)) {
        _gruaIdSeleccionada = gruaIdApi;
      } else {
        _gruaIdPendiente = gruaIdApi;
      }
    }

    if (_gruaIdSeleccionada == null && gruaIdByNombre != null) {
      _gruaIdSeleccionada = gruaIdByNombre;
      _gruaIdPendiente = null;
    }

    final corralonIdApi = _primerEnteroEnRutas(data, [
      ['corralon_id'],
      ['corralonGruaId'],
      ['corralon_grua_id'],
      ['servicio', 'corralon_id'],
      ['corralon', 'id'],
      ['servicio', 'corralon', 'id'],
    ]);
    _corralonNombreCargado = _primerTextoEnRutas(data, [
      ['corralon_nombre'],
      ['corralon'],
      ['servicio', 'corralon_nombre'],
      ['corralon', 'nombre'],
      ['servicio', 'corralon', 'nombre'],
    ]);
    final corralonIdByNombre = _idGruaPorNombre(_corralonNombreCargado);

    _corralonGruaIdSeleccionada = null;
    _corralonGruaIdPendiente = null;

    if (corralonIdApi != null) {
      if (_gruaIdExisteEnLista(corralonIdApi)) {
        _corralonGruaIdSeleccionada = corralonIdApi;
      } else {
        _corralonGruaIdPendiente = corralonIdApi;
      }
    }

    if (_corralonGruaIdSeleccionada == null && corralonIdByNombre != null) {
      _corralonGruaIdSeleccionada = corralonIdByNombre;
      _corralonGruaIdPendiente = null;
    }

    if (!mounted) return;
    setState(() {
      _loading = false;

      _aplicarPendientesSiSePuede();

      if (_gruaIdSeleccionada == null && !_cargandoGruas) {
        final gruaIdByNombre = _idGruaPorNombre(_gruaNombreCargado);
        if (gruaIdByNombre != null) {
          _gruaIdSeleccionada = gruaIdByNombre;
          _gruaIdPendiente = null;
        }
      }

      if (_corralonGruaIdSeleccionada == null && !_cargandoGruas) {
        final corralonIdByNombre = _idGruaPorNombre(_corralonNombreCargado);
        if (corralonIdByNombre != null) {
          _corralonGruaIdSeleccionada = corralonIdByNombre;
          _corralonGruaIdPendiente = null;
        }
      }
    });
  }

  Future<void> _guardar() async {
    if (!_argsOk) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Error'),
          content: Text('Faltan hechoId/vehiculoId (ruta mal llamada).'),
        ),
      );
      return;
    }

    if (!await _validateFormAndScroll()) return;

    final validationError = VehiculoFormService.validateVehiculoBeforeSubmit(
      marca: _t(_marcaCtrl),
      linea: _t(_lineaCtrl),
      color: _t(_colorCtrl),
      tipoServicio: _t(_tipoServicioCtrl),
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
          hechoId: _hechoId,
          hechoClientUuid: null,
          existingVehiculos: _vehiculosSnapshot,
          currentVehiculoId: _vehiculoId,
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
      final uri = Uri.parse(
        '$_baseApi/hechos/$_hechoId/vehiculos/$_vehiculoId',
      );

      final corralonNombre = _nombreGruaById(_corralonGruaIdSeleccionada);

      final placasClean = _limpiaPlacas(_t(_placasCtrl));
      final estadoClean = VehiculoFormService.normalizeEstadoPlacas(
        _estadoPlacasSeleccionado,
      );

      final tipoCarroceria = _canonCarroceria(
        _tipoGeneralSeleccionado,
        _tipoCarroceriaSeleccionada,
      );

      final payload = <String, dynamic>{
        'marca': _t(_marcaCtrl),
        'modelo': _t(_modeloCtrl).isEmpty ? null : _t(_modeloCtrl),
        'tipo': (tipoCarroceria ?? '').trim(),
        'linea': _t(_lineaCtrl),
        'color': _t(_colorCtrl),
        'placas': placasClean.isEmpty ? null : placasClean,
        'estado_placas': placasClean.isEmpty ? null : estadoClean,
        'serie': VehiculoFormService.normalizeSerie(_t(_serieCtrl)),
        'capacidad_personas': _toIntOrNull(_t(_capacidadCtrl)) ?? 0,
        'tipo_servicio': _t(_tipoServicioCtrl),
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
        method: 'PUT',
        uri: uri,
        body: payload,
        successCodes: const <int>{200},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo actualizar el vehículo.\n\n$e'),
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
    if (!_argsOk) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar vehículo')),
        body: const Center(child: Text('Falta hechoId/vehiculoId.')),
      );
    }

    final carroceriasDisponibles = _carroceriasDeTipoGeneral(
      _tipoGeneralSeleccionado,
    );
    final tienePlacas = _limpiaPlacas(_t(_placasCtrl)).isNotEmpty;
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
        title: Text('Editar vehículo (#$_vehiculoId)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _saving ? null : _cargarVehiculo,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _marcaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Marca *',
                        prefixIcon: Icon(Icons.local_offer),
                      ),
                      validator: (v) =>
                          VehiculoFormService.validateRequiredText(
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
                          : (v) =>
                                setState(() => _tipoCarroceriaSeleccionada = v),
                      validator: (v) {
                        if ((_tipoGeneralSeleccionado ?? '').isEmpty) {
                          return null;
                        }
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
                      validator: (v) =>
                          VehiculoFormService.validateRequiredText(
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
                      validator: (v) =>
                          VehiculoFormService.validateOptionalText(
                            v,
                            max: 10,
                            label: 'Modelo',
                          ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: colorSeleccionado.isEmpty
                          ? null
                          : colorSeleccionado,
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
                      onChanged: (v) => setState(() => _setColor(v)),
                      validator: (v) =>
                          VehiculoFormService.validateRequiredText(
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
                      onChanged: (_) => setState(() {}),
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
                        onChanged: (v) =>
                            setState(() => _estadoPlacasSeleccionado = v),
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
                    TextFormField(
                      controller: _tipoServicioCtrl,
                      decoration: const InputDecoration(
                        labelText:
                            'Tipo de servicio * (PARTICULAR, PÚBLICO, etc.)',
                        prefixIcon: Icon(Icons.miscellaneous_services),
                      ),
                      validator: (v) =>
                          VehiculoFormService.validateRequiredText(
                            v,
                            max: 50,
                            label: 'Tipo de servicio',
                          ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _tarjetaCirculacionNombreCtrl,
                      decoration: const InputDecoration(
                        labelText:
                            'Nombre tarjeta circulación (opcional, máx 60)',
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (v) =>
                          VehiculoFormService.validateOptionalText(
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
                            value: _gruaIdExisteEnLista(_gruaIdSeleccionada)
                                ? _gruaIdSeleccionada
                                : null,
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
                            onChanged: (v) =>
                                setState(() => _gruaIdSeleccionada = v),
                          ),
                    const SizedBox(height: 10),
                    _cargandoGruas
                        ? const SizedBox.shrink()
                        : DropdownButtonFormField<int?>(
                            value:
                                _gruaIdExisteEnLista(
                                  _corralonGruaIdSeleccionada,
                                )
                                ? _corralonGruaIdSeleccionada
                                : null,
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
                            onChanged: (v) =>
                                setState(() => _corralonGruaIdSeleccionada = v),
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
                      onChanged: (value) =>
                          setState(() => _setAseguradora(value)),
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
                      validator: (v) =>
                          VehiculoFormService.validateRequiredText(
                            v,
                            max: 10000,
                            label: 'Partes dañadas',
                          ),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      title: const Text('Antecedente del vehículo'),
                      value: _antecedenteVehiculo,
                      onChanged: (v) =>
                          setState(() => _antecedenteVehiculo = v),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _guardar,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _saving ? 'Guardando...' : 'Actualizar vehículo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

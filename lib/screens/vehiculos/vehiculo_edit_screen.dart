import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import '../../core/vehiculos/vehiculo_taxonomia.dart';
import '../../core/vehiculos/estados_republica.dart';

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

  String? _corralonNombreCargado;

  static const String _baseApi = 'https://seguridadvial-mich.com/api';
  static const String _urlGruas = '$_baseApi/gruas';

  int _hechoId = 0;
  int _vehiculoId = 0;
  bool _argsOk = false;
  bool _inicializo = false;

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

  String _limpiaPlacas(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'[\s\-\._,]'), '');

  String? _req(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Requerido';
    return null;
  }

  String? _maxLenOrNull(String? v, int max) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (s.length > max) return 'Máximo $max caracteres';
    return null;
  }

  String? _capacidadValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Requerido';
    final n = int.tryParse(s);
    if (n == null) return 'Debe ser número';
    if (n < 0) return 'No puede ser negativo';
    return null;
  }

  String? _montoValidator(String? v, {bool required = false}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return required ? 'Requerido' : null;
    final n = double.tryParse(s);
    if (n == null) return 'Debe ser número';
    if (n < 0) return 'No puede ser negativo';
    return null;
  }

  String? _tipoGeneralValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Requerido';
    return null;
  }

  String? _tipoCarroceriaValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Requerido';
    return null;
  }

  String? _placasValidator(String? v) {
    final s = _limpiaPlacas(v ?? '');
    if (s.isEmpty) return null;
    final ok = RegExp(r'^[A-Z0-9]{5,15}$').hasMatch(s);
    if (!ok) return 'Placas inválidas (solo letras y números, 5-15)';
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

  bool _gruaIdExisteEnLista(int? id) {
    if (id == null) return false;
    for (final g in _gruas) {
      final gid = int.tryParse((g['id'] ?? '').toString());
      if (gid == id) return true;
    }
    return false;
  }

  int? _idGruaPorNombre(String? nombre) {
    final n = (nombre ?? '').trim();
    if (n.isEmpty) return null;
    for (final g in _gruas) {
      final gid = int.tryParse((g['id'] ?? '').toString());
      final nom = (g['nombre'] ?? '').toString().trim();
      if (gid != null &&
          nom.isNotEmpty &&
          nom.toUpperCase() == n.toUpperCase()) {
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
    final v = (apiValue ?? '').trim().toUpperCase();
    if (v.isEmpty) return null;

    for (final e in EstadosRepublica.estados) {
      final value = (e['value'] ?? '').trim().toUpperCase();
      final label = (e['label'] ?? '').trim().toUpperCase();
      if (value == v || label == v) return e['value'];
    }

    return null;
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
      final h = await _headers();
      final res = await http.get(Uri.parse(_urlGruas), headers: h);

      if (res.statusCode != 200) {
        final msg = _apiErrorText(
          res,
          fallbackTitle: 'No se pudieron cargar grúas',
        );
        throw Exception(msg);
      }

      final raw = jsonDecode(_decodeBody(res));

      List list;
      if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List;
      } else if (raw is List) {
        list = raw;
      } else {
        list = [];
      }

      _gruas = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() {
        _cargandoGruas = false;

        _aplicarPendientesSiSePuede();

        if (_corralonGruaIdSeleccionada == null &&
            _corralonGruaIdPendiente == null) {
          _corralonGruaIdSeleccionada = _idGruaPorNombre(
            _corralonNombreCargado,
          );
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
    _aseguradoraCtrl.text = (data['aseguradora'] ?? '').toString();
    _montoDanosCtrl.text = (data['monto_danos'] ?? '').toString();
    _partesDanadasCtrl.text = (data['partes_danadas'] ?? '').toString();
    _antecedenteVehiculo = (data['antecedente_vehiculo'] == true);

    final tipoGeneralApi = (data['tipo_general'] ?? '').toString().trim();
    final carroceriaApi = (data['tipo'] ?? '').toString().trim();

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

    final gruaIdApi = int.tryParse((data['grua_id'] ?? '').toString());
    _gruaIdSeleccionada = null;
    _gruaIdPendiente = null;

    if (gruaIdApi != null && gruaIdApi > 0) {
      if (_gruaIdExisteEnLista(gruaIdApi)) {
        _gruaIdSeleccionada = gruaIdApi;
      } else {
        _gruaIdPendiente = gruaIdApi;
      }
    }

    _corralonNombreCargado = (data['corralon'] ?? '').toString().trim();
    final corralonIdByNombre = _idGruaPorNombre(_corralonNombreCargado);

    if (corralonIdByNombre != null &&
        _gruaIdExisteEnLista(corralonIdByNombre)) {
      _corralonGruaIdSeleccionada = corralonIdByNombre;
      _corralonGruaIdPendiente = null;
    } else {
      _corralonGruaIdSeleccionada = null;
      _corralonGruaIdPendiente = null;
    }

    if (!mounted) return;
    setState(() {
      _loading = false;

      _aplicarPendientesSiSePuede();

      if (_corralonGruaIdSeleccionada == null && !_cargandoGruas) {
        _corralonGruaIdSeleccionada = _idGruaPorNombre(_corralonNombreCargado);
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

    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final h = await _headers(json: true);
      final uri = Uri.parse(
        '$_baseApi/hechos/$_hechoId/vehiculos/$_vehiculoId',
      );

      final corralonNombre = _nombreGruaById(_corralonGruaIdSeleccionada);

      final placasClean = _limpiaPlacas(_t(_placasCtrl));
      final estadoClean = (_estadoPlacasSeleccionado ?? '')
          .trim()
          .toUpperCase();

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
        'estado_placas': placasClean.isEmpty
            ? null
            : (estadoClean.isEmpty ? null : estadoClean),
        'serie': _t(_serieCtrl).isEmpty ? null : _t(_serieCtrl),
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

      final res = await http.put(uri, headers: h, body: jsonEncode(payload));

      if (res.statusCode != 200) {
        final msg = _apiErrorText(
          res,
          fallbackTitle: 'No se pudo actualizar el vehículo',
        );
        throw Exception(msg);
      }

      if (!mounted) return;
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
                      validator: _req,
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
                        if ((_tipoGeneralSeleccionado ?? '').isEmpty)
                          return null;
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
                      validator: _req,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _modeloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Modelo (opcional, máx 10)',
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                      validator: (v) => _maxLenOrNull(v, 10),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _colorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Color *',
                        prefixIcon: Icon(Icons.color_lens),
                      ),
                      validator: _req,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _placasCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Placas (opcional)',
                        prefixIcon: Icon(Icons.credit_card),
                      ),
                      validator: _placasValidator,
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
                      validator: (v) => _maxLenOrNull(v, 17),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _capacidadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Capacidad de personas *',
                        prefixIcon: Icon(Icons.people),
                      ),
                      validator: _capacidadValidator,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _tipoServicioCtrl,
                      decoration: const InputDecoration(
                        labelText:
                            'Tipo de servicio * (PARTICULAR, PÚBLICO, etc.)',
                        prefixIcon: Icon(Icons.miscellaneous_services),
                      ),
                      validator: _req,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _tarjetaCirculacionNombreCtrl,
                      decoration: const InputDecoration(
                        labelText:
                            'Nombre tarjeta circulación (opcional, máx 60)',
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (v) => _maxLenOrNull(v, 60),
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
                                final id = int.tryParse(
                                  (g['id'] ?? '').toString(),
                                );
                                final nombre = (g['nombre'] ?? '').toString();
                                return DropdownMenuItem<int?>(
                                  value: id,
                                  child: Text(
                                    nombre.isEmpty ? 'GRÚA #$id' : nombre,
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
                                final id = int.tryParse(
                                  (g['id'] ?? '').toString(),
                                );
                                final nombre = (g['nombre'] ?? '').toString();
                                return DropdownMenuItem<int?>(
                                  value: id,
                                  child: Text(
                                    nombre.isEmpty ? 'CORRALÓN #$id' : nombre,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (v) =>
                                setState(() => _corralonGruaIdSeleccionada = v),
                          ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _aseguradoraCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Aseguradora (opcional)',
                        prefixIcon: Icon(Icons.security),
                      ),
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
                      validator: (v) => _montoValidator(v, required: true),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _partesDanadasCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Partes dañadas *',
                        prefixIcon: Icon(Icons.car_crash),
                      ),
                      validator: _req,
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import '../../core/vehiculos/vehiculo_taxonomia.dart';
import '../../core/vehiculos/estados_republica.dart';
import '../../services/offline_sync_service.dart';
import '../../services/vehiculo_form_service.dart';

class VehiculoCreateScreen extends StatefulWidget {
  const VehiculoCreateScreen({super.key});

  @override
  State<VehiculoCreateScreen> createState() => _VehiculoCreateScreenState();
}

class _VehiculoCreateScreenState extends State<VehiculoCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

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
  static const String _urlGruas = '$_baseApi/gruas';

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
    if (_cargandoGruas) {
      _cargarGruas();
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

  String? _tipoGeneralValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Requerido';
    return null;
  }

  String? _tipoCarroceriaValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Requerido';
    return null;
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sin token. Inicia sesión otra vez.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
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

  Future<void> _cargarGruas() async {
    try {
      final h = await _headers();
      final res = await http.get(Uri.parse(_urlGruas), headers: h);

      if (res.statusCode != 200) {
        final msg = _apiErrorText(
          res,
          fallbackTitle: 'No se pudieron cargar grúas',
        );
        if (!mounted) return;
        setState(() => _cargandoGruas = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }

      final body = _decodeBody(res);
      final raw = jsonDecode(body);

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
      _gruaIdSeleccionada = null;
      _corralonGruaIdSeleccionada = null;

      if (!mounted) return;
      setState(() => _cargandoGruas = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoGruas = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar grúas: $e')),
      );
    }
  }

  List<String> _carroceriasDeTipoGeneral(String? tipoGeneral) {
    return VehiculoTaxonomia.carroceriasDeTipoGeneral(tipoGeneral);
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

  Future<void> _guardar({
    required int hechoId,
    required String? hechoClientUuid,
  }) async {
    final normalizedHechoClientUuid = (hechoClientUuid ?? '').trim();
    final vehiculosSnapshot = _vehiculosSnapshotFromArgs(context);
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

    if (!_formKey.currentState!.validate()) return;

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
      final clientUuid = OfflineSyncService.newClientUuid();
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
                    : (v) => setState(() => _tipoCarroceriaSeleccionada = v),
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
              TextFormField(
                controller: _colorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Color *',
                  prefixIcon: Icon(Icons.color_lens),
                ),
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
                  labelText: 'Tipo de servicio * (PARTICULAR, PÚBLICO, etc.)',
                  prefixIcon: Icon(Icons.miscellaneous_services),
                ),
                validator: (v) => VehiculoFormService.validateRequiredText(
                  v,
                  max: 50,
                  label: 'Tipo de servicio',
                ),
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
                          final id = int.tryParse((g['id'] ?? '').toString());
                          final nombre = (g['nombre'] ?? '').toString();
                          return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(nombre.isEmpty ? 'GRÚA #$id' : nombre),
                          );
                        }),
                      ],
                      onChanged: (v) => setState(() => _gruaIdSeleccionada = v),
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
                          final id = int.tryParse((g['id'] ?? '').toString());
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
                validator: (v) => VehiculoFormService.validateOptionalText(
                  v,
                  max: 100,
                  label: 'Aseguradora',
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
                onChanged: (v) => setState(() => _antecedenteVehiculo = v),
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

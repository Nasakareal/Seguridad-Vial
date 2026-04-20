import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/auth_service.dart';
import '../../services/vehiculo_form_service.dart';

class VehiculoConductorCreateScreen extends StatefulWidget {
  const VehiculoConductorCreateScreen({super.key});

  @override
  State<VehiculoConductorCreateScreen> createState() =>
      _VehiculoConductorCreateScreenState();
}

class _VehiculoConductorCreateScreenState
    extends State<VehiculoConductorCreateScreen> {
  bool _cargando = true;
  bool _guardando = false;

  int hechoId = 0;
  int vehiculoId = 0;

  Map<String, dynamic> _vehiculo = {};
  List<Map<String, dynamic>> _vehiculosSnapshot = const [];

  final _formKey = GlobalKey<FormState>();

  // conductor
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _domicilioCtrl = TextEditingController();
  final _ocupacionCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _tipoLicenciaCtrl = TextEditingController();
  final _estadoLicenciaCtrl = TextEditingController();
  final _numeroLicenciaCtrl = TextEditingController();
  DateTime? _vigenciaLicencia;
  String? _sexo;

  bool _permanente = false;
  bool _cinturon = false;
  bool _antecedenteConductor = false;
  bool _certificadoLesiones = false;
  bool _certificadoAlcoholemia = false;
  bool _alientoEtilico = false;

  // ✅ para evitar recargas/rellenados al seleccionar dropdown
  bool _loadedOnce = false;
  bool _prefilledOnce = false;

  Map<String, dynamic> _args(BuildContext context) {
    final a = ModalRoute.of(context)?.settings.arguments;
    if (a is Map) return Map<String, dynamic>.from(a);
    return {};
  }

  String _safeText(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '' : s;
  }

  int _toInt(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

  bool _toBool(dynamic v) {
    if (v is bool) return v;
    final s = (v ?? '').toString().toLowerCase().trim();
    return s == '1' || s == 'true' || s == 'si' || s == 'sí';
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  bool _hasUserTypedSomething() {
    return _nombreCtrl.text.trim().isNotEmpty ||
        _telefonoCtrl.text.trim().isNotEmpty ||
        _domicilioCtrl.text.trim().isNotEmpty ||
        _ocupacionCtrl.text.trim().isNotEmpty ||
        _edadCtrl.text.trim().isNotEmpty ||
        _tipoLicenciaCtrl.text.trim().isNotEmpty ||
        _estadoLicenciaCtrl.text.trim().isNotEmpty ||
        _numeroLicenciaCtrl.text.trim().isNotEmpty ||
        _sexo != null ||
        _vigenciaLicencia != null ||
        _permanente ||
        _cinturon ||
        _antecedenteConductor ||
        _certificadoLesiones ||
        _certificadoAlcoholemia ||
        _alientoEtilico;
  }

  Future<void> _cargarVehiculo() async {
    if (hechoId <= 0 || vehiculoId <= 0) {
      if (!mounted) return;
      setState(() => _cargando = false);
      return;
    }

    setState(() => _cargando = true);

    final h = await _headers();
    final uri = Uri.parse(
      'https://seguridadvial-mich.com/api/hechos/$hechoId/vehiculos/$vehiculoId',
    );
    final res = await http.get(uri, headers: h);

    if (res.statusCode != 200) {
      if (!mounted) return;
      setState(() => _cargando = false);
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final raw = jsonDecode(res.body);
    Map<String, dynamic> data;

    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      data = Map<String, dynamic>.from(raw['data']);
    } else if (raw is Map<String, dynamic>) {
      data = raw;
    } else {
      data = {};
    }

    _vehiculo = data;

    // ✅ Prefill SOLO una vez, y SOLO si el usuario no empezó a editar
    if (!_prefilledOnce && !_hasUserTypedSomething()) {
      final conductores = data['conductores'];
      if (conductores is List &&
          conductores.isNotEmpty &&
          conductores.first is Map) {
        final c = Map<String, dynamic>.from(conductores.first as Map);

        _nombreCtrl.text = _safeText(c['nombre']);
        _telefonoCtrl.text = _safeText(c['telefono']);
        _domicilioCtrl.text = _safeText(c['domicilio']);

        final sx = _safeText(c['sexo']);
        _sexo = sx.isEmpty ? null : sx;

        _ocupacionCtrl.text = _safeText(c['ocupacion']);
        _edadCtrl.text = _safeText(c['edad']);

        _tipoLicenciaCtrl.text = _safeText(c['tipo_licencia']);
        _estadoLicenciaCtrl.text = _safeText(c['estado_licencia']);
        _numeroLicenciaCtrl.text = _safeText(c['numero_licencia']);

        final vig = _safeText(c['vigencia_licencia']);
        if (vig.isNotEmpty) {
          _vigenciaLicencia = DateTime.tryParse(vig);
        }

        _permanente = _toBool(c['permanente']);
        _cinturon = _toBool(c['cinturon']);
        // ojo con el nombre de campo: en tu GET usabas "antecedentes"
        _antecedenteConductor =
            _toBool(c['antecedente_conductor']) || _toBool(c['antecedentes']);
        _certificadoLesiones = _toBool(c['certificado_lesiones']);
        _certificadoAlcoholemia = _toBool(c['certificado_alcoholemia']);
        _alientoEtilico = _toBool(c['aliento_etilico']);

        _prefilledOnce = true;
      }
    }

    if (!mounted) return;
    setState(() => _cargando = false);
  }

  Future<void> _pickVigencia() async {
    final now = DateTime.now();
    final init = _vigenciaLicencia ?? DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _vigenciaLicencia = picked);
    }
  }

  Future<void> _scanLicencia() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _LicenciaScannerScreen()),
    );
    final text = raw?.trim() ?? '';
    if (text.isEmpty || !mounted) return;

    final parsed = VehiculoFormService.parseLicenciaConducirQr(text);
    final applied = _applyLicenciaData(parsed);

    if (!mounted) return;
    if (applied > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se llenaron $applied campos desde la licencia.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Licencia leída'),
        content: const Text(
          'No pude identificar nombre, tipo o vigencia en el código. Captura manualmente o comparte un ejemplo del texto crudo para ajustar el lector.',
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

  int _applyLicenciaData(ConductorLicenseQrData parsed) {
    var applied = 0;

    bool setText(TextEditingController controller, String? value) {
      final cleaned = (value ?? '').trim();
      if (cleaned.isEmpty || controller.text.trim() == cleaned) return false;
      controller.text = cleaned;
      return true;
    }

    bool sameDate(DateTime? a, DateTime? b) {
      if (a == null || b == null) return a == b;
      return a.year == b.year && a.month == b.month && a.day == b.day;
    }

    setState(() {
      if (setText(_nombreCtrl, parsed.nombre)) applied += 1;
      if (setText(_tipoLicenciaCtrl, parsed.tipoLicencia)) applied += 1;

      if (parsed.permanente) {
        if (!_permanente || _vigenciaLicencia != null) {
          _permanente = true;
          _vigenciaLicencia = null;
          applied += 1;
        }
      } else if (parsed.vigencia != null) {
        if (_permanente || !sameDate(_vigenciaLicencia, parsed.vigencia)) {
          _permanente = false;
          _vigenciaLicencia = parsed.vigencia;
          applied += 1;
        }
      }
    });

    return applied;
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_formKey.currentState!.validate()) return;

    final validationError = VehiculoFormService.validateConductorBeforeSubmit(
      nombre: _nombreCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      domicilio: _domicilioCtrl.text.trim(),
      sexo: _sexo,
      ocupacion: _ocupacionCtrl.text.trim(),
      edad: _edadCtrl.text.trim(),
      tipoLicencia: _tipoLicenciaCtrl.text.trim(),
      estadoLicencia: _estadoLicenciaCtrl.text.trim(),
      numeroLicencia: _numeroLicenciaCtrl.text.trim(),
    );
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final duplicateError =
        await VehiculoFormService.validateConductorDuplicatesWithinHecho(
          hechoId: hechoId,
          hechoClientUuid: null,
          existingVehiculos: _vehiculosSnapshot,
          currentVehiculoId: vehiculoId,
          conductorNombre: _nombreCtrl.text.trim(),
        );
    if (duplicateError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(duplicateError)));
      return;
    }

    setState(() => _guardando = true);

    try {
      final h = await _headers();

      // ✅ Normaliza para no mandar null donde tu backend a veces espera string/int
      final body = <String, dynamic>{
        // ===== VEHICULO (reenviados como venían del GET) =====
        'marca': (_vehiculo['marca'] ?? '').toString(),
        'modelo': _vehiculo['modelo'],
        'tipo': (_vehiculo['tipo'] ?? '').toString(),
        'linea': (_vehiculo['linea'] ?? '').toString(),
        'color': (_vehiculo['color'] ?? '').toString(),
        'placas': (_vehiculo['placas'] ?? '').toString(),
        'estado_placas': _vehiculo['estado_placas'],
        'serie': _vehiculo['serie'],
        'capacidad_personas': _toInt(_vehiculo['capacidad_personas']),
        'tipo_servicio': (_vehiculo['tipo_servicio'] ?? '').toString(),
        'tarjeta_circulacion_nombre': _vehiculo['tarjeta_circulacion_nombre'],
        'grua_id': _vehiculo['grua_id'], // si lo manejas, respeta lo que venga
        'corralon': _vehiculo['corralon'],
        'aseguradora': _vehiculo['aseguradora'],
        'monto_danos': _vehiculo['monto_danos'] ?? 0,
        'partes_danadas': (_vehiculo['partes_danadas'] ?? '').toString(),
        'antecedente_vehiculo': _toBool(_vehiculo['antecedente_vehiculo']),

        // ===== CONDUCTOR =====
        'conductor_nombre': _nombreCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim().isEmpty
            ? null
            : _telefonoCtrl.text.trim(),
        'domicilio': _domicilioCtrl.text.trim().isEmpty
            ? null
            : _domicilioCtrl.text.trim(),
        'sexo': _sexo,
        'ocupacion': _ocupacionCtrl.text.trim().isEmpty
            ? null
            : _ocupacionCtrl.text.trim(),
        'edad': _edadCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_edadCtrl.text.trim()),

        'tipo_licencia': _tipoLicenciaCtrl.text.trim().isEmpty
            ? null
            : _tipoLicenciaCtrl.text.trim(),
        'estado_licencia': _estadoLicenciaCtrl.text.trim().isEmpty
            ? null
            : _estadoLicenciaCtrl.text.trim(),
        'numero_licencia': _numeroLicenciaCtrl.text.trim().isNotEmpty
            ? _numeroLicenciaCtrl.text.trim()
            : null,

        'permanente': _permanente,
        'vigencia_licencia': _permanente
            ? null
            : _vigenciaLicencia?.toIso8601String().substring(0, 10),

        'cinturon': _cinturon,
        'antecedente_conductor': _antecedenteConductor,
        'certificado_lesiones': _certificadoLesiones,
        'certificado_alcoholemia': _certificadoAlcoholemia,
        'aliento_etilico': _alientoEtilico,
      };

      final uri = Uri.parse(
        'https://seguridadvial-mich.com/api/hechos/$hechoId/vehiculos/$vehiculoId',
      );

      final res = await http.put(uri, headers: h, body: jsonEncode(body));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conductor guardado correctamente.')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ Cargar argumentos y API SOLO una vez
    if (_loadedOnce) return;
    _loadedOnce = true;

    final a = _args(context);
    hechoId = int.tryParse((a['hechoId'] ?? 0).toString()) ?? 0;
    vehiculoId = int.tryParse((a['vehiculoId'] ?? 0).toString()) ?? 0;
    if (a['vehiculosSnapshot'] is List) {
      _vehiculosSnapshot = (a['vehiculosSnapshot'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    // evitar llamar setState aquí si no hace falta
    if (hechoId > 0 && vehiculoId > 0) {
      _cargarVehiculo();
    } else {
      setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _domicilioCtrl.dispose();
    _ocupacionCtrl.dispose();
    _edadCtrl.dispose();
    _tipoLicenciaCtrl.dispose();
    _estadoLicenciaCtrl.dispose();
    _numeroLicenciaCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Conductor (Vehículo #$vehiculoId)')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _guardando ? null : _scanLicencia,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Escanear licencia de conducir'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del conductor',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) =>
                          VehiculoFormService.validateRequiredText(
                            v,
                            max: 255,
                            label: 'Nombre del conductor',
                          ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _telefonoCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono (10 dígitos)',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: VehiculoFormService.validateTelefono,
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _domicilioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Domicilio',
                        prefixIcon: Icon(Icons.home),
                      ),
                      validator: (v) =>
                          VehiculoFormService.validateOptionalText(
                            v,
                            max: 255,
                            label: 'Domicilio',
                          ),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: _sexo,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Sexo',
                        prefixIcon: Icon(Icons.badge),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'MASCULINO',
                          child: Text('MASCULINO'),
                        ),
                        DropdownMenuItem(
                          value: 'FEMENINO',
                          child: Text('FEMENINO'),
                        ),
                        DropdownMenuItem(value: 'OTRO', child: Text('OTRO')),
                      ],
                      onChanged: (v) {
                        // ✅ solo esto, sin recargar nada
                        setState(() => _sexo = v);
                      },
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _ocupacionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ocupación',
                        prefixIcon: Icon(Icons.work),
                      ),
                      validator: (v) =>
                          VehiculoFormService.validateOptionalText(
                            v,
                            max: 255,
                            label: 'Ocupación',
                          ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _edadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Edad',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator: VehiculoFormService.validateEdad,
                    ),

                    const Divider(height: 24),

                    SwitchListTile(
                      title: const Text('Licencia permanente'),
                      value: _permanente,
                      onChanged: (v) => setState(() => _permanente = v),
                    ),
                    const SizedBox(height: 6),

                    if (!_permanente)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Vigencia licencia'),
                        subtitle: Text(
                          _vigenciaLicencia == null
                              ? '—'
                              : _fmtDate(_vigenciaLicencia!),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.date_range),
                          onPressed: _pickVigencia,
                        ),
                      ),

                    TextFormField(
                      controller: _tipoLicenciaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de licencia',
                      ),
                      validator: (v) =>
                          VehiculoFormService.validateOptionalText(
                            v,
                            max: 50,
                            label: 'Tipo de licencia',
                          ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _estadoLicenciaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Estado de licencia',
                      ),
                      validator: (v) =>
                          VehiculoFormService.validateOptionalText(
                            v,
                            max: 100,
                            label: 'Estado de licencia',
                          ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _numeroLicenciaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Número de licencia',
                      ),
                      validator: (v) =>
                          VehiculoFormService.validateOptionalText(
                            v,
                            max: 50,
                            label: 'Número de licencia',
                          ),
                    ),

                    const Divider(height: 24),

                    SwitchListTile(
                      title: const Text('Cinturón'),
                      value: _cinturon,
                      onChanged: (v) => setState(() => _cinturon = v),
                    ),
                    SwitchListTile(
                      title: const Text('Antecedente conductor'),
                      value: _antecedenteConductor,
                      onChanged: (v) =>
                          setState(() => _antecedenteConductor = v),
                    ),
                    SwitchListTile(
                      title: const Text('Certificado lesiones'),
                      value: _certificadoLesiones,
                      onChanged: (v) =>
                          setState(() => _certificadoLesiones = v),
                    ),
                    SwitchListTile(
                      title: const Text('Certificado alcoholemia'),
                      value: _certificadoAlcoholemia,
                      onChanged: (v) =>
                          setState(() => _certificadoAlcoholemia = v),
                    ),
                    SwitchListTile(
                      title: const Text('Aliento etílico'),
                      value: _alientoEtilico,
                      onChanged: (v) => setState(() => _alientoEtilico = v),
                    ),

                    const SizedBox(height: 18),

                    ElevatedButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _guardando ? 'Guardando...' : 'Guardar conductor',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _LicenciaScannerScreen extends StatefulWidget {
  const _LicenciaScannerScreen();

  @override
  State<_LicenciaScannerScreen> createState() => _LicenciaScannerScreenState();
}

class _LicenciaScannerScreenState extends State<_LicenciaScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
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
        title: const Text('Escanear licencia'),
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
              width: 280,
              height: 180,
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
                'Apunta al código de la licencia. Se llenarán nombre, tipo y vigencia cuando el formato sea reconocible.',
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

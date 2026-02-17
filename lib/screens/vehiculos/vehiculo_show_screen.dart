import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';

class VehiculoShowScreen extends StatefulWidget {
  const VehiculoShowScreen({super.key});

  @override
  State<VehiculoShowScreen> createState() => _VehiculoShowScreenState();
}

class _VehiculoShowScreenState extends State<VehiculoShowScreen> {
  bool _loading = true;
  String? _error;

  int _hechoId = 0;
  int _vehiculoId = 0;
  bool _argsOk = false;
  bool _inicializo = false;

  Map<String, dynamic> _vehiculo = {};
  List<Map<String, dynamic>> _conductores = [];
  String? _fotoUrl;

  static const String _baseApi = 'https://seguridadvial-mich.com/api';

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
      _loadAll();
    } else {
      setState(() {
        _loading = false;
        _error = 'Falta hechoId/vehiculoId.';
      });
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sin token. Inicia sesión otra vez.');
    }
    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
  }

  String _decodeBody(http.Response res) {
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return res.body;
    }
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asListOfMap(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  String _v(String key) {
    final val = _vehiculo[key];
    final s = (val ?? '').toString().trim();
    return s.isEmpty ? 'N/A' : s;
  }

  String _money(String key) {
    final val = _vehiculo[key];
    if (val == null) return 'N/A';
    final s = val.toString().trim();
    if (s.isEmpty) return 'N/A';
    return s;
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([_loadVehiculo(), _loadFoto()]);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadVehiculo() async {
    final h = await _headers();
    final uri = Uri.parse('$_baseApi/hechos/$_hechoId/vehiculos/$_vehiculoId');
    final res = await http.get(uri, headers: h);

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${_decodeBody(res)}');
    }

    final raw = jsonDecode(_decodeBody(res));
    final map = _asMap(raw);
    final data = map.containsKey('data') ? _asMap(map['data']) : map;

    _vehiculo = data;
    _conductores = _asListOfMap(data['conductores']);
  }

  Future<void> _loadFoto() async {
    final h = await _headers();
    final uri = Uri.parse(
      '$_baseApi/hechos/$_hechoId/vehiculos/$_vehiculoId/foto',
    );
    final res = await http.get(uri, headers: h);

    if (res.statusCode != 200) {
      _fotoUrl = null;
      return;
    }

    final raw = jsonDecode(_decodeBody(res));
    final map = _asMap(raw);
    final data = map.containsKey('data') ? _asMap(map['data']) : map;

    final url = (data['url'] ?? '').toString().trim();
    _fotoUrl = url.isEmpty ? null : url;
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        t,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _fotoBox() {
    if (_fotoUrl == null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('Sin foto')),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          _fotoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: Colors.black12,
              child: const Center(child: Text('No se pudo cargar la foto')),
            );
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  Widget _conductorCard(Map<String, dynamic> c) {
    String _s(String key) {
      final v = (c[key] ?? '').toString().trim();
      return v.isEmpty ? 'N/A' : v;
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _s('nombre'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _kv('Teléfono', _s('telefono')),
            _kv('Domicilio', _s('domicilio')),
            _kv('Sexo', _s('sexo')),
            _kv('Ocupación', _s('ocupacion')),
            _kv('Edad', _s('edad')),
            _kv('Licencia', _s('tipo_licencia')),
            _kv('Estado licencia', _s('estado_licencia')),
            _kv('No. licencia', _s('numero_licencia')),
            _kv('Vigencia', _s('vigencia_licencia')),
            _kv('Permanente', (c['permanente'] == true) ? 'Sí' : 'No'),
            _kv('Cinturón', (c['cinturon'] == true) ? 'Sí' : 'No'),
            _kv('Antecedente', (c['antecedentes'] == true) ? 'Sí' : 'No'),
            _kv(
              'Cert. lesiones',
              (c['certificado_lesiones'] == true) ? 'Sí' : 'No',
            ),
            _kv(
              'Cert. alcoholemia',
              (c['certificado_alcoholemia'] == true) ? 'Sí' : 'No',
            ),
            _kv(
              'Aliento etílico',
              (c['aliento_etilico'] == true) ? 'Sí' : 'No',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_argsOk) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehículo')),
        body: Center(child: Text(_error ?? 'Falta hechoId/vehiculoId.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Vehículo #$_vehiculoId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  _fotoBox(),
                  _sectionTitle('Datos del vehículo'),
                  _kv('Marca', _v('marca')),
                  _kv('Línea', _v('linea')),
                  _kv('Tipo general', _v('tipo_general')),
                  _kv('Carrocería', _v('tipo')),
                  _kv('Modelo', _v('modelo')),
                  _kv('Color', _v('color')),
                  _kv('Placas', _v('placas')),
                  _kv('Estado placas', _v('estado_placas')),
                  _kv('NIV/Serie', _v('serie')),
                  _kv('Capacidad', _v('capacidad_personas')),
                  _kv('Tipo servicio', _v('tipo_servicio')),
                  _kv('Tarjeta circulación', _v('tarjeta_circulacion_nombre')),
                  _kv('Grúa', _v('grua_nombre')),
                  _kv('Corralón', _v('corralon')),
                  _kv('Aseguradora', _v('aseguradora')),
                  _kv('Monto daños', _money('monto_danos')),
                  _kv('Partes dañadas', _v('partes_danadas')),
                  _kv(
                    'Antecedente',
                    (_vehiculo['antecedente_vehiculo'] == true) ? 'Sí' : 'No',
                  ),
                  _sectionTitle('Conductor(es)'),
                  if (_conductores.isEmpty)
                    const Text('Sin conductor registrado.')
                  else
                    ..._conductores.map(_conductorCard).toList(),
                ],
              ),
            ),
    );
  }
}

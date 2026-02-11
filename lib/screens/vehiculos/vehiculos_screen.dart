import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';

class VehiculosScreen extends StatefulWidget {
  const VehiculosScreen({super.key});

  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {
  bool _cargando = true;
  List<Map<String, dynamic>> _vehiculos = [];

  int _hechoId = 0;
  bool _yaCargo = false;

  final _picker = ImagePicker();

  int _safeInt(dynamic v) {
    if (v == null) return 0;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _safeText(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  String _conductorNombre(Map<String, dynamic> vehiculo) {
    final c = vehiculo['conductores'];
    if (c is List && c.isNotEmpty) {
      final first = c.first;
      if (first is Map) return _safeText(first['nombre']);
    }
    return '—';
  }

  String? _fotoPath(Map<String, dynamic> vehiculo) {
    final f = vehiculo['fotos'];
    final s = (f ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  bool _tieneFoto(Map<String, dynamic> vehiculo) => _fotoPath(vehiculo) != null;

  String _fotoUrlFromPath(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return 'https://seguridadvial-mich.com/storage/$p';
  }

  String _fotoUrl(Map<String, dynamic> vehiculo) {
    final path = _fotoPath(vehiculo);
    if (path == null) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return _fotoUrlFromPath(path);
  }

  Future<Map<String, String>> _headersJson() async {
    final token = await AuthService.getToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _vehiculosUri() => Uri.parse(
    'https://seguridadvial-mich.com/api/hechos/$_hechoId/vehiculos',
  );

  Uri _fotoApiUri(int vehiculoId) => Uri.parse(
    'https://seguridadvial-mich.com/api/hechos/$_hechoId/vehiculos/$vehiculoId/foto',
  );

  Future<void> _cargarVehiculos() async {
    if (_hechoId <= 0) {
      if (!mounted) return;
      setState(() {
        _vehiculos = [];
        _cargando = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final headers = await _headersJson();
      final res = await http.get(_vehiculosUri(), headers: headers);

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final raw = jsonDecode(res.body);

      List<dynamic> datos;
      if (raw is List) {
        datos = raw;
      } else if (raw is Map<String, dynamic> && raw['data'] is List) {
        datos = raw['data'] as List<dynamic>;
      } else if (raw is Map<String, dynamic> && raw['vehiculos'] is List) {
        datos = raw['vehiculos'] as List<dynamic>;
      } else {
        datos = [];
      }

      final items = datos
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _vehiculos = items;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cargando vehículos: $e')));
    }
  }

  Future<void> _irCrearVehiculo() async {
    if (_hechoId <= 0) return;

    await Navigator.pushNamed(
      context,
      '/accidentes/vehiculos/create',
      arguments: {'hechoId': _hechoId},
    );
    await _cargarVehiculos();
  }

  Future<void> _irEditarVehiculo({required int vehiculoId}) async {
    if (_hechoId <= 0 || vehiculoId <= 0) return;

    await Navigator.pushNamed(
      context,
      '/accidentes/vehiculos/edit',
      arguments: {'hechoId': _hechoId, 'vehiculoId': vehiculoId},
    );
    await _cargarVehiculos();
  }

  Future<void> _irCrearEditarConductor({required int vehiculoId}) async {
    if (_hechoId <= 0 || vehiculoId <= 0) return;

    await Navigator.pushNamed(
      context,
      '/accidentes/vehiculos/conductor/create',
      arguments: {'hechoId': _hechoId, 'vehiculoId': vehiculoId},
    );
    await _cargarVehiculos();
  }

  Future<void> _mostrarAccionesFoto(Map<String, dynamic> vehiculo) async {
    final vehiculoId = _safeInt(vehiculo['id']);
    if (vehiculoId <= 0) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final tiene = _tieneFoto(vehiculo);
        final url = _fotoUrl(vehiculo);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 10,
              children: [
                Text(
                  'Foto del vehículo #$vehiculoId',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (tiene)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('No se pudo cargar la imagen'),
                        ),
                      ),
                    ),
                  )
                else
                  const Text('Este vehículo no tiene foto todavía.'),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _seleccionarYSubirFoto(vehiculoId: vehiculoId);
                        },
                        icon: const Icon(Icons.upload),
                        label: Text(tiene ? 'Reemplazar' : 'Subir'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: tiene
                            ? () async {
                                Navigator.pop(context);
                                await _eliminarFoto(vehiculoId: vehiculoId);
                              }
                            : null,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        );
      },
    );

    await _cargarVehiculos();
  }

  Future<void> _seleccionarYSubirFoto({required int vehiculoId}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final len = await file.length();
    const maxBytes = 2 * 1024 * 1024;
    if (len > maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La imagen supera 2MB. Elige otra o comprímela.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final token = await AuthService.getToken();
      final req = http.MultipartRequest('POST', _fotoApiUri(vehiculoId));
      req.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty)
        req.headers['Authorization'] = 'Bearer $token';

      req.files.add(await http.MultipartFile.fromPath('foto', file.path));

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;
      Navigator.pop(context);

      if (res.statusCode != 200 && res.statusCode != 201) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto subida correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error subiendo foto: $e')));
    }

    await _cargarVehiculos();
  }

  Future<void> _eliminarFoto({required int vehiculoId}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text(
          '¿Seguro que quieres eliminar la foto de este vehículo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final headers = await _headersJson();
      final res = await http.delete(_fotoApiUri(vehiculoId), headers: headers);

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto eliminada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error eliminando foto: $e')));
    }

    await _cargarVehiculos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_yaCargo) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['hechoId'] != null) {
      _hechoId = int.tryParse(args['hechoId'].toString()) ?? 0;
    } else {
      _hechoId = 0;
    }

    _yaCargo = true;
    _cargarVehiculos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vehículos (Hecho #$_hechoId)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarVehiculos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _vehiculos.isEmpty
          ? const Center(child: Text('No hay vehículos registrados.'))
          : ListView.builder(
              itemCount: _vehiculos.length,
              itemBuilder: (_, i) {
                final v = _vehiculos[i];

                final vehiculoId = _safeInt(v['id']);
                final marca = _safeText(v['marca']);
                final linea = _safeText(v['linea']);
                final placas = _safeText(v['placas']);
                final modelo = _safeText(v['modelo']);
                final conductor = _conductorNombre(v);
                final tieneFoto = _tieneFoto(v);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        const Icon(Icons.directions_car),
                        if (tieneFoto)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.photo, size: 16),
                          ),
                      ],
                    ),
                    title: Text('$marca $linea'),
                    subtitle: Text(
                      'Placas: $placas  •  Modelo: $modelo\nConductor: $conductor',
                    ),
                    isThreeLine: true,
                    onTap: vehiculoId > 0
                        ? () => _irEditarVehiculo(vehiculoId: vehiculoId)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Foto',
                          icon: const Icon(Icons.photo_camera),
                          onPressed: vehiculoId > 0
                              ? () => _mostrarAccionesFoto(v)
                              : null,
                        ),
                        IconButton(
                          tooltip: 'Editar vehículo',
                          icon: const Icon(Icons.edit),
                          onPressed: vehiculoId > 0
                              ? () => _irEditarVehiculo(vehiculoId: vehiculoId)
                              : null,
                        ),
                        IconButton(
                          tooltip: 'Agregar/Editar conductor',
                          icon: const Icon(Icons.person_add_alt_1),
                          onPressed: vehiculoId > 0
                              ? () => _irCrearEditarConductor(
                                  vehiculoId: vehiculoId,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _hechoId > 0 ? _irCrearVehiculo : null,
        child: const Icon(Icons.add),
      ),
    );
  }
}

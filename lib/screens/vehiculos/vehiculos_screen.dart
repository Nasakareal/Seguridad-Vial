import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/landscape_photo_crop_screen.dart';
import '../../widgets/safe_network_image.dart';

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

  String? _inventarioPath(Map<String, dynamic> vehiculo) {
    final f = vehiculo['foto_inventario_grua'];
    final s = (f ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  String? _numeroInventario(Map<String, dynamic> vehiculo) {
    final s = (vehiculo['numero_inventario_grua'] ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  bool _tieneInventario(Map<String, dynamic> vehiculo) {
    return _numeroInventario(vehiculo) != null ||
        _inventarioPath(vehiculo) != null;
  }

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

  String _inventarioUrl(Map<String, dynamic> vehiculo) {
    final path = _inventarioPath(vehiculo);
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

  Uri _inventarioApiUri(int vehiculoId) => Uri.parse(
    'https://seguridadvial-mich.com/api/hechos/$_hechoId/vehiculos/$vehiculoId/inventario-grua',
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
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
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
      arguments: {'hechoId': _hechoId, 'vehiculosSnapshot': _vehiculos},
    );
    await _cargarVehiculos();
  }

  Future<void> _irEditarVehiculo({required int vehiculoId}) async {
    if (_hechoId <= 0 || vehiculoId <= 0) return;

    await Navigator.pushNamed(
      context,
      '/accidentes/vehiculos/edit',
      arguments: {
        'hechoId': _hechoId,
        'vehiculoId': vehiculoId,
        'vehiculosSnapshot': _vehiculos,
      },
    );
    await _cargarVehiculos();
  }

  Future<void> _irCrearEditarConductor({required int vehiculoId}) async {
    if (_hechoId <= 0 || vehiculoId <= 0) return;

    await Navigator.pushNamed(
      context,
      '/accidentes/vehiculos/conductor/create',
      arguments: {
        'hechoId': _hechoId,
        'vehiculoId': vehiculoId,
        'vehiculosSnapshot': _vehiculos,
      },
    );
    await _cargarVehiculos();
  }

  void _irLesionados() {
    if (_hechoId <= 0) return;

    Navigator.pushNamed(
      context,
      AppRoutes.lesionados,
      arguments: {'hechoId': _hechoId},
    );
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
                      child: SafeNetworkImage(
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
      maxHeight: 2000,
    );
    if (picked == null || !mounted) return;

    final file = await LandscapePhotoCropScreen.cropIfNeeded(
      context,
      File(picked.path),
    );
    if (file == null) return;
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
      if (token != null && token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }

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

  Future<Map<String, dynamic>> _consultarInventario({
    required int vehiculoId,
  }) async {
    final headers = await _headersJson();
    final res = await http.get(_inventarioApiUri(vehiculoId), headers: headers);

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final raw = jsonDecode(res.body);
    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    if (raw is Map<String, dynamic>) return raw;
    return <String, dynamic>{};
  }

  Future<void> _mostrarAccionesInventario(Map<String, dynamic> vehiculo) async {
    final vehiculoId = _safeInt(vehiculo['id']);
    if (vehiculoId <= 0) return;

    Map<String, dynamic> inventario = <String, dynamic>{};

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      inventario = await _consultarInventario(vehiculoId: vehiculoId);
    } catch (e) {
      inventario = Map<String, dynamic>.from(vehiculo);
    } finally {
      if (mounted) Navigator.pop(context);
    }

    if (!mounted) return;

    final numeroCtrl = TextEditingController(
      text:
          (inventario['numero_inventario_grua'] ??
                  _numeroInventario(vehiculo) ??
                  '')
              .toString(),
    );
    File? selectedFile;
    var saving = false;

    final currentUrl = (inventario['url'] ?? '').toString().trim().isNotEmpty
        ? inventario['url'].toString().trim()
        : _inventarioUrl(vehiculo);
    final hasCurrentInventory =
        numeroCtrl.text.trim().isNotEmpty || currentUrl.trim().isNotEmpty;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickInventoryPhoto() async {
              final picked = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 2400,
                maxHeight: 2400,
              );
              if (picked == null || !mounted || !context.mounted) return;

              final file = await LandscapePhotoCropScreen.cropIfNeeded(
                context,
                File(picked.path),
              );
              if (file == null) return;

              final len = await file.length();
              const maxBytes = 4 * 1024 * 1024;
              if (len > maxBytes) {
                if (!mounted || !context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La imagen supera 4MB. Elige otra o comprímela.',
                    ),
                  ),
                );
                return;
              }

              setModalState(() => selectedFile = file);
            }

            Future<void> saveInventory() async {
              final numero = numeroCtrl.text.trim();
              if (numero.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Captura el numero de inventario.'),
                  ),
                );
                return;
              }

              setModalState(() => saving = true);
              try {
                await _guardarInventario(
                  vehiculoId: vehiculoId,
                  numeroInventario: numero,
                  foto: selectedFile,
                );
                if (!mounted || !context.mounted || !sheetContext.mounted) {
                  return;
                }
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inventario guardado.')),
                );
              } catch (e) {
                if (!mounted || !context.mounted) return;
                setModalState(() => saving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error guardando inventario: $e')),
                );
              }
            }

            Future<void> deleteInventory() async {
              setModalState(() => saving = true);
              try {
                await _eliminarInventario(vehiculoId: vehiculoId);
                if (!mounted || !context.mounted || !sheetContext.mounted) {
                  return;
                }
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inventario eliminado.')),
                );
              } catch (e) {
                if (!mounted || !context.mounted) return;
                setModalState(() => saving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error eliminando inventario: $e')),
                );
              }
            }

            final bottom = MediaQuery.of(context).viewInsets.bottom;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Inventario del vehículo #$vehiculoId',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selectedFile != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.file(selectedFile!, fit: BoxFit.cover),
                          ),
                        )
                      else if (currentUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: SafeNetworkImage(
                              currentUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text('No se pudo cargar la imagen'),
                              ),
                            ),
                          ),
                        )
                      else
                        const Text(
                          'Este vehículo no tiene inventario todavía.',
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: numeroCtrl,
                        enabled: !saving,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Numero de inventario',
                          prefixIcon: Icon(Icons.confirmation_number),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: saving ? null : pickInventoryPhoto,
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                selectedFile != null || currentUrl.isNotEmpty
                                    ? 'Reemplazar foto'
                                    : 'Subir foto',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: saving ? null : saveInventory,
                              icon: const Icon(Icons.save),
                              label: Text(saving ? 'Guardando...' : 'Guardar'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close),
                              label: const Text('Cerrar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: saving || !hasCurrentInventory
                                  ? null
                                  : deleteInventory,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Eliminar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    numeroCtrl.dispose();
    await _cargarVehiculos();
  }

  Future<void> _guardarInventario({
    required int vehiculoId,
    required String numeroInventario,
    File? foto,
  }) async {
    final token = await AuthService.getToken();
    final req = http.MultipartRequest('POST', _inventarioApiUri(vehiculoId));
    req.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.fields['numero_inventario_grua'] = numeroInventario;
    if (foto != null) {
      req.files.add(
        await http.MultipartFile.fromPath('foto_inventario_grua', foto.path),
      );
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> _eliminarInventario({required int vehiculoId}) async {
    final headers = await _headersJson();
    final res = await http.delete(
      _inventarioApiUri(vehiculoId),
      headers: headers,
    );

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
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
                final tieneInventario = _tieneInventario(v);
                final inventario = _numeroInventario(v);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            const Icon(Icons.directions_car),
                            if (tieneFoto || tieneInventario)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(
                                  tieneInventario
                                      ? Icons.inventory_2
                                      : Icons.photo,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                        title: Text('$marca $linea'),
                        subtitle: Text(
                          [
                            'Placas: $placas  •  Modelo: $modelo',
                            'Conductor: $conductor',
                            if ((inventario ?? '').isNotEmpty)
                              'Inventario: $inventario',
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        onTap: vehiculoId > 0
                            ? () => _irEditarVehiculo(vehiculoId: vehiculoId)
                            : null,
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              tooltip: 'Editar vehículo',
                              icon: const Icon(Icons.edit),
                              onPressed: vehiculoId > 0
                                  ? () => _irEditarVehiculo(
                                      vehiculoId: vehiculoId,
                                    )
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
                            IconButton(
                              tooltip: 'Foto del vehículo',
                              icon: const Icon(Icons.photo_camera),
                              onPressed: vehiculoId > 0
                                  ? () => _mostrarAccionesFoto(v)
                                  : null,
                            ),
                            IconButton(
                              tooltip: 'Inventario',
                              icon: const Icon(Icons.inventory_2),
                              onPressed: vehiculoId > 0
                                  ? () => _mostrarAccionesInventario(v)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _hechoId > 0 ? _irCrearVehiculo : null,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton.icon(
            onPressed: _hechoId > 0 ? _irLesionados : null,
            icon: const Icon(Icons.personal_injury),
            label: const Text('Agregar / ver lesionados'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

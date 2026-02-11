import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';

class ControlUbicacionScreen extends StatefulWidget {
  const ControlUbicacionScreen({super.key});

  @override
  State<ControlUbicacionScreen> createState() => _ControlUbicacionScreenState();
}

class _ControlUbicacionScreenState extends State<ControlUbicacionScreen> {
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  String _q = '';

  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  static const String _baseUrl = 'https://seguridadvial-mich.com/api';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  bool _toBool(dynamic v) {
    if (v == true) return true;
    if (v == false) return false;
    if (v is num) return v == 1;
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'si' || s == 'sí' || s == 'on';
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '$_baseUrl/mi-personal?q=${Uri.encodeQueryComponent(_q)}',
      );
      final res = await http.get(uri, headers: await _headers());

      if (res.statusCode != 200) {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body);

      final list = (decoded is Map && decoded['data'] is List)
          ? (decoded['data'] as List)
          : (decoded is List ? decoded : <dynamic>[]);

      final items = <Map<String, dynamic>>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) items.add(e);
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  Future<void> _limpiarUbicacionUsuario(int userId) async {
    final uri = Uri.parse('$_baseUrl/mi-personal/$userId/ubicacion/limpiar');
    final res = await http.post(uri, headers: await _headers());

    // 200 esperado, pero si falla no tumba todo
    if (res.statusCode != 200) {
      throw Exception(
        'No se pudo limpiar ubicaciones: ${res.statusCode}: ${res.body}',
      );
    }
  }

  Future<void> _limpiarUbicacionTodos() async {
    final uri = Uri.parse('$_baseUrl/mi-personal/ubicacion/limpiar-todos');
    final res = await http.post(uri, headers: await _headers());

    if (res.statusCode != 200) {
      throw Exception(
        'No se pudo limpiar ubicaciones (todos): ${res.statusCode}: ${res.body}',
      );
    }
  }

  Future<void> _setUbicacionUsuario({
    required int userId,
    required bool enabled,
  }) async {
    if (_guardando) return;
    _guardando = true;

    final idx = _items.indexWhere((x) => (x['id'] ?? 0) == userId);
    Map<String, dynamic>? prev;
    if (idx >= 0) {
      prev = Map<String, dynamic>.from(_items[idx]);
      setState(() {
        _items[idx] = {..._items[idx], 'compartir_ubicacion': enabled ? 1 : 0};
      });
    }

    try {
      final uri = Uri.parse('$_baseUrl/mi-personal/$userId/ubicacion');
      final res = await http.post(
        uri,
        headers: await _headers(),
        body: jsonEncode({'enabled': enabled}),
      );

      if (res.statusCode != 200) {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      // Sincroniza valor desde respuesta
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['data'] is Map) {
        final d = decoded['data'] as Map;
        final newVal = d['compartir_ubicacion'];
        if (idx >= 0 && mounted) {
          setState(() {
            _items[idx] = {..._items[idx], 'compartir_ubicacion': newVal};
          });
        }
      }

      // ✅ Si se desactiva, el backend ya borró user_locations.
      // Pero si quieres “doble seguro”, descomenta este bloque:
      if (!enabled) {
        try {
          await _limpiarUbicacionUsuario(userId);
        } catch (_) {
          // No hacemos drama; el toggle ya funcionó.
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Ubicación activada' : 'Ubicación desactivada y limpiada',
          ),
        ),
      );
    } catch (e) {
      if (idx >= 0 && prev != null && mounted) {
        setState(() => _items[idx] = prev!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      _guardando = false;
    }
  }

  Future<void> _setUbicacionTodos({required bool enabled}) async {
    if (_guardando) return;
    _guardando = true;

    final prev = _items.map((e) => Map<String, dynamic>.from(e)).toList();
    setState(() {
      _items = _items
          .map((e) => {...e, 'compartir_ubicacion': enabled ? 1 : 0})
          .toList();
    });

    try {
      final uri = Uri.parse('$_baseUrl/mi-personal/ubicacion/todos');
      final res = await http.post(
        uri,
        headers: await _headers(),
        body: jsonEncode({'enabled': enabled}),
      );

      if (res.statusCode != 200) {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      // ✅ Si se desactiva, el backend ya borró user_locations de todos.
      // Doble seguro opcional:
      if (!enabled) {
        try {
          await _limpiarUbicacionTodos();
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Ubicación activada para tu personal'
                : 'Ubicación desactivada y limpiada para tu personal',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _items = prev);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo aplicar a todos: $e')));
    } finally {
      _guardando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final activos = _items
        .where((e) => _toBool(e['compartir_ubicacion']))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Control de ubicación (Mi personal)'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Personal: $total   ·   Activos: $activos',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    if (_guardando)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o correo…',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF6F7FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  onChanged: (v) => _q = v.trim(),
                  onSubmitted: (_) => _cargar(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _guardando
                            ? null
                            : () => _setUbicacionTodos(enabled: true),
                        icon: const Icon(Icons.location_on),
                        label: const Text('Activar todos'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _guardando
                            ? null
                            : () => _setUbicacionTodos(enabled: false),
                        icon: const Icon(Icons.location_off),
                        label: const Text('Desactivar + limpiar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error:\n$_error',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _items.isEmpty
                ? const Center(child: Text('Sin personal para mostrar.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final it = _items[i];
                      final id = (it['id'] ?? 0) as int;
                      final nombre = (it['name'] ?? 'Sin nombre').toString();
                      final email = (it['email'] ?? '').toString();
                      final area = (it['area'] ?? '').toString();

                      final enabled = _toBool(it['compartir_ubicacion']);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: enabled
                                ? Colors.green.withOpacity(.12)
                                : Colors.red.withOpacity(.12),
                            child: Icon(
                              enabled ? Icons.location_on : Icons.location_off,
                              color: enabled ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            nombre,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (email.isNotEmpty) Text(email),
                              if (area.isNotEmpty) Text(area),
                            ],
                          ),
                          isThreeLine: (email.isNotEmpty && area.isNotEmpty),
                          trailing: Switch(
                            value: enabled,
                            onChanged: _guardando
                                ? null
                                : (v) => _setUbicacionUsuario(
                                    userId: id,
                                    enabled: v,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

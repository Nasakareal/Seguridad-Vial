import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';

class HechosBusquedaScreen extends StatefulWidget {
  const HechosBusquedaScreen({super.key});

  @override
  State<HechosBusquedaScreen> createState() => _HechosBusquedaScreenState();
}

class _HechosBusquedaScreenState extends State<HechosBusquedaScreen> {
  final TextEditingController _c = TextEditingController();
  final FocusNode _focus = FocusNode();

  Timer? _debounce;

  bool _cargando = false;
  bool _cargandoMas = false;
  String? _error;

  String _q = '';
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  int _page = 1;
  int _lastPage = 1;

  static const String _baseUrl = 'https://seguridadvial-mich.com/api';
  static const String _host = 'https://seguridadvial-mich.com';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () {
      final s = v.trim();
      if (s.length < 2) {
        setState(() {
          _q = s;
          _items = <Map<String, dynamic>>[];
          _page = 1;
          _lastPage = 1;
          _cargando = false;
          _cargandoMas = false;
          _error = null;
        });
        return;
      }
      _buscar(s, reset: true);
    });
  }

  Future<void> _buscar(String q, {required bool reset}) async {
    if (_cargando) return;

    setState(() {
      _cargando = true;
      _error = null;
      _q = q;
      if (reset) {
        _items = <Map<String, dynamic>>[];
        _page = 1;
        _lastPage = 1;
      }
    });

    try {
      final res = await _fetchPage(q, page: 1);
      if (!mounted) return;

      setState(() {
        _items = res.items;
        _page = res.page;
        _lastPage = res.lastPage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo buscar: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _cargarMas() async {
    if (_cargandoMas) return;
    if (_cargando) return;
    if (_q.trim().length < 2) return;
    if (_page >= _lastPage) return;

    setState(() => _cargandoMas = true);

    try {
      final next = _page + 1;
      final res = await _fetchPage(_q, page: next);

      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _page = res.page;
        _lastPage = res.lastPage;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cargar más: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _cargandoMas = false);
    }
  }

  Future<_SearchResponse> _fetchPage(String q, {required int page}) async {
    final uri = Uri.parse('$_baseUrl/hechos/buscar').replace(
      queryParameters: <String, String>{
        'q': q,
        'per_page': '20',
        'page': page.toString(),
      },
    );

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    final list = (decoded is Map && decoded['data'] is List)
        ? (decoded['data'] as List)
        : <dynamic>[];

    final meta = (decoded is Map && decoded['meta'] is Map)
        ? (decoded['meta'] as Map)
        : <dynamic, dynamic>{};

    final items = <Map<String, dynamic>>[];
    for (final e in list) {
      if (e is Map) items.add(Map<String, dynamic>.from(e));
    }

    final currentPage = (meta['current_page'] is int)
        ? (meta['current_page'] as int)
        : page;

    final lastPage = (meta['last_page'] is int)
        ? (meta['last_page'] as int)
        : page;

    return _SearchResponse(items: items, page: currentPage, lastPage: lastPage);
  }

  void _openHecho(Map<String, dynamic> row) {
    final id = row['id'];
    if (id == null) return;

    final hechoId = (id is int) ? id : int.tryParse('$id');
    if (hechoId == null) return;

    Navigator.pushNamed(
      context,
      '/accidentes/show',
      arguments: {'hechoId': hechoId},
    );
  }

  // ============================================================
  // Helpers
  // ============================================================
  String _safeText(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '' : s;
  }

  String? _toAbsoluteUrl(String? raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return null;

    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('/')) return '$_host$s';
    if (s.startsWith('storage/')) return '$_host/$s';

    if (s.contains('/') && !s.startsWith('/storage/')) {
      return '$_host/storage/$s';
    }

    return null;
  }

  // ============================================================
  // FOTO DEL HECHO = foto_lugar (no foto_situacion)
  // ============================================================
  String? _fotoFromRow(Map<String, dynamic> row) {
    final candidates = [
      'foto_lugar_url',
      'foto_lugar',
      'foto_hecho_url',
      'foto_hecho',
      'foto',
      'foto_url',
      'imagen',
      'imagen_url',
      'thumb',
      'thumbnail',
    ];

    for (final k in candidates) {
      final abs = _toAbsoluteUrl(_safeText(row[k]));
      if (abs != null) return abs;
    }
    return null;
  }

  // ============================================================
  // PERITO: debe venir como row['perito'] (string) en /hechos/buscar
  // Si NO viene, aquí no hay forma mágica: el backend debe incluirlo.
  // Aun así, lo buscamos en varias llaves para compat.
  // ============================================================
  String _peritoFromRow(Map<String, dynamic> row) {
    final direct = [
      'perito',
      'perito_nombre',
      'nombre_perito',
      'perito_asignado',
    ];

    for (final k in direct) {
      final s = _safeText(row[k]);
      if (s.isNotEmpty) return s;
    }

    // por si luego mandas objetos
    final peritoObj = row['perito_obj'] ?? row['perito_user'] ?? row['user'];
    if (peritoObj is Map) {
      final name = _safeText(peritoObj['name'] ?? peritoObj['nombre']);
      if (name.isNotEmpty) return name;
    }

    return '';
  }

  // ============================================================
  // Título: sin folio_c5i
  // ============================================================
  String _titleFromRow(Map<String, dynamic> row) {
    final id = _safeText(row['id']);
    final fecha = _safeText(row['fecha']);
    final left = id.isNotEmpty ? 'Hecho #$id' : 'Hecho';
    return fecha.isNotEmpty ? '$left · $fecha' : left;
  }

  // ============================================================
  // Ubicación: calle + colonia (lo que pediste)
  // ============================================================
  String _ubicacion(Map<String, dynamic> row) {
    final calle = _safeText(row['calle']);
    final col = _safeText(row['colonia']);

    final parts = <String>[];
    if (calle.isNotEmpty) parts.add(calle);
    if (col.isNotEmpty) parts.add(col);

    return parts.isEmpty ? 'Sin ubicación' : parts.join(', ');
  }

  String _vehiculoResumen(Map<String, dynamic> row) {
    String placas = '';
    String serie = '';
    String conductor = '';

    final vehs = row['vehiculos'];
    if (vehs is List && vehs.isNotEmpty) {
      final v0 = vehs.first;
      if (v0 is Map) {
        placas = _safeText(v0['placas']);
        serie = _safeText(v0['serie']);

        final conds = v0['conductores'];
        if (conds is List && conds.isNotEmpty) {
          final c0 = conds.first;
          if (c0 is Map) {
            conductor = _safeText(c0['nombre']);
          }
        }
      }
    }

    final parts = <String>[];
    if (placas.isNotEmpty) parts.add('Placas: $placas');
    if (serie.isNotEmpty) parts.add('Serie: $serie');
    if (conductor.isNotEmpty) parts.add('Conductor: $conductor');

    return parts.isEmpty ? '' : parts.join(' · ');
  }

  void _limpiar() {
    _debounce?.cancel();
    _c.clear();
    setState(() {
      _q = '';
      _items = <Map<String, dynamic>>[];
      _page = 1;
      _lastPage = 1;
      _cargando = false;
      _cargandoMas = false;
      _error = null;
    });
    _focus.requestFocus();
  }

  // ============================================================
  // Leading foto
  // ============================================================
  Widget _leadingFoto(Map<String, dynamic> row) {
    final url = _fotoFromRow(row);
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.blue.withOpacity(.12),
        child: const Icon(Icons.photo, color: Colors.blue),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        color: Colors.grey.shade200,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(.12),
              child: const Icon(Icons.broken_image, color: Colors.blue),
            );
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: (progress.expectedTotalBytes != null)
                      ? progress.cumulativeBytesLoaded /
                            (progress.expectedTotalBytes ?? 1)
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // ✅ NUEVO: subtítulo forzado en 3 renglones fijos:
  // 1) ubicación
  // 2) perito (SIEMPRE reserva espacio aunque esté vacío)
  // 3) placas/serie/conductor
  //
  // Esto evita que el layout "se coma" el perito por falta de espacio.
  // ============================================================
  Widget _subtitleWidget(Map<String, dynamic> row) {
    final ubicacion = _ubicacion(row);
    final perito = _peritoFromRow(row);
    final veh = _vehiculoResumen(row);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ubicacion, maxLines: 2, overflow: TextOverflow.ellipsis),

        // 👇 AQUÍ VA JUSTO DEBAJO DE LA DIRECCIÓN (como pediste)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            perito.trim().isNotEmpty ? 'Perito: $perito' : 'Perito: —',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black54,
            ),
          ),
        ),

        if (veh.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              veh,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSearch = _c.text.trim().length >= 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Búsqueda'),
        backgroundColor: Colors.blue,
        actions: [
          if (_c.text.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar',
              icon: const Icon(Icons.close),
              onPressed: _limpiar,
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
                    const Icon(Icons.search, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Buscar hechos',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    if (_cargando)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _c,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    final s = v.trim();
                    if (s.length >= 2) _buscar(s, reset: true);
                  },
                  decoration: InputDecoration(
                    hintText: 'Placas, serie, conductor, calle, colonia…',
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (!canSearch)
                  const Text(
                    'Escribe al menos 2 letras para buscar.',
                    style: TextStyle(color: Colors.black54),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Error: $_error',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _cargando && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? _EmptyState(q: _q, canSearch: canSearch)
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels >=
                          (n.metrics.maxScrollExtent - 200)) {
                        _cargarMas();
                      }
                      return false;
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: _items.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == _items.length) {
                          if (_cargandoMas) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return const SizedBox(height: 4);
                        }

                        final row = _items[i];

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            onTap: () => _openHecho(row),

                            leading: _leadingFoto(row),

                            // ✅ importantísimo: dale más aire a la tarjeta
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),

                            // ✅ para que respete bien el alto del subtitle
                            isThreeLine: true,

                            title: Text(
                              _titleFromRow(row),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),

                            // ✅ subtítulo fijo: dirección -> perito -> vehículo
                            subtitle: _subtitleWidget(row),

                            trailing: Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String q;
  final bool canSearch;

  const _EmptyState({required this.q, required this.canSearch});

  @override
  Widget build(BuildContext context) {
    final text = canSearch
        ? 'Sin resultados para "$q".'
        : 'Escribe algo para buscar.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 54, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResponse {
  final List<Map<String, dynamic>> items;
  final int page;
  final int lastPage;

  const _SearchResponse({
    required this.items,
    required this.page,
    required this.lastPage,
  });
}

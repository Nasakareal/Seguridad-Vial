import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/app_version_service.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/header_card.dart';

import '../login_screen.dart';
import '../../main.dart' show AppRoutes;

class HechoShowScreen extends StatefulWidget {
  const HechoShowScreen({super.key});

  @override
  State<HechoShowScreen> createState() => _HechoShowScreenState();
}

class _HechoShowScreenState extends State<HechoShowScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _hecho;
  bool _cargando = true;

  bool _trackingOn = false;
  bool _bootstrapped = false;
  bool _busy = false;

  static const List<String> _sectorOptions = [
    'REVOLUCIÓN',
    'NUEVA ESPAÑA',
    'INDEPENDENCIA',
    'REPÚBLICA',
    'CENTRO',
  ];

  static const List<String> _situacionOptions = [
    'RESUELTO',
    'PENDIENTE',
    'TURNADO',
    'REPORTE',
  ];

  int _hechoIdFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    int parse(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    if (args == null) return 0;

    final direct = parse(args);
    if (direct > 0) return direct;

    if (args is Map) {
      final candidates = [
        args['hechoId'],
        args['hecho_id'],
        args['id'],
        args['item_id'],
      ];

      for (final c in candidates) {
        final id = parse(c);
        if (id > 0) return id;
      }
    }

    return 0;
  }

  String _safeText(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  String _safeBool01(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    if (s.isEmpty) return '—';
    if (s == '1' || s.toLowerCase() == 'true') return 'Sí';
    if (s == '0' || s.toLowerCase() == 'false') return 'No';
    return s;
  }

  String _normalizeSector(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    if (_sectorOptions.contains(s)) return s;

    final upper = s.toUpperCase();
    for (final opt in _sectorOptions) {
      if (upper.contains(opt.toUpperCase())) return opt;
    }
    return s.toUpperCase();
  }

  String _normalizeSituacion(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    if (_situacionOptions.contains(s)) return s;

    final upper = s.toUpperCase();
    for (final opt in _situacionOptions) {
      if (upper.contains(opt)) return opt;
    }
    return s.toUpperCase();
  }

  String _toPublicUrl(String pathOrUrl) {
    final p = pathOrUrl.trim();
    if (p.isEmpty) return '';

    final lower = p.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return p;

    final root = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

    if (p.startsWith('/storage/')) return '$root$p';
    if (p.startsWith('storage/')) return '$root/$p';

    return '$root/storage/$p';
  }

  List<Map<String, dynamic>> _vehiculosDeHecho() {
    final v = _hecho?['vehiculos'];

    // Caso normal: vehiculos = [ ... ]
    if (v is List) {
      return v
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    // Caso paginado: vehiculos = { data: [ ... ] }
    if (v is Map) {
      final data = v['data'];
      if (data is List) {
        return data
            .where((e) => e is Map)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }

    return const [];
  }

  /// Fotos de VEHICULOS (fotos / fotos_url).
  List<String> _fotosVehiculosDelHecho() {
    final vehs = _vehiculosDeHecho();
    final out = <String>[];

    for (final v in vehs) {
      final fotosUrl = v['fotos_url'];
      if (fotosUrl is String && fotosUrl.trim().isNotEmpty) {
        out.add(fotosUrl.trim());
        continue;
      }

      final fotos = v['fotos'];
      if (fotos == null) continue;

      if (fotos is List) {
        for (final x in fotos) {
          final s = (x ?? '').toString().trim();
          if (s.isNotEmpty) out.add(_toPublicUrl(s));
        }
        continue;
      }

      if (fotos is String) {
        final s = fotos.trim();
        if (s.isEmpty) continue;

        if (s.startsWith('[') && s.endsWith(']')) {
          try {
            final decoded = jsonDecode(s);
            if (decoded is List) {
              for (final x in decoded) {
                final ss = (x ?? '').toString().trim();
                if (ss.isNotEmpty) out.add(_toPublicUrl(ss));
              }
              continue;
            }
          } catch (_) {}
        }

        out.add(_toPublicUrl(s));
      }
    }

    final uniq = <String>{};
    final cleaned = <String>[];
    for (final u in out) {
      final uu = u.trim();
      if (uu.isEmpty) continue;
      if (uniq.add(uu)) cleaned.add(uu);
    }
    return cleaned;
  }

  /// Foto del hecho + foto de situación (vienen directo del HECHO).
  String _fotoLugarUrl() {
    final h = _hecho ?? {};
    final raw =
        (h['foto_lugar_url'] ?? h['foto_lugar_path'] ?? h['foto_lugar'] ?? '')
            .toString()
            .trim();
    return raw.isEmpty ? '' : _toPublicUrl(raw);
  }

  String _fotoSituacionUrl() {
    final h = _hecho ?? {};
    final raw =
        (h['foto_situacion_url'] ??
                h['foto_situacion_path'] ??
                h['foto_situacion'] ??
                '')
            .toString()
            .trim();
    return raw.isEmpty ? '' : _toPublicUrl(raw);
  }

  Future<void> _bootstrapTrackingStatusOnly() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final running = await FlutterForegroundTask.isRunningService;
    if (!mounted) return;
    setState(() => _trackingOn = running);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppVersionService.enforceUpdateIfNeeded(context);
      await _bootstrapTrackingStatusOnly();

      final id = _hechoIdFromArgs(context);
      if (id > 0) {
        await _cargarHecho(id);
      } else if (mounted) {
        setState(() => _cargando = false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final running = await FlutterForegroundTask.isRunningService;
      if (!mounted) return;
      setState(() => _trackingOn = running);
    }
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      await TrackingService.stop();
      await AuthService.logout();
    } finally {
      _busy = false;
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _cargarHecho(int id) async {
    if (!mounted) return;
    setState(() => _cargando = true);

    final token = await AuthService.getToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse('${AuthService.baseUrl}/hechos/$id');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      if (mounted) setState(() => _cargando = false);
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final raw = jsonDecode(res.body);
    Map<String, dynamic> hecho;

    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      hecho = Map<String, dynamic>.from(raw['data']);
    } else if (raw is Map<String, dynamic> && raw['hecho'] is Map) {
      hecho = Map<String, dynamic>.from(raw['hecho']);
    } else if (raw is Map<String, dynamic>) {
      hecho = raw;
    } else {
      hecho = {};
    }

    if (!mounted) return;
    setState(() {
      _hecho = hecho;
      _cargando = false;
    });
  }

  Future<void> _goEdit(int hechoId) async {
    if (hechoId <= 0) return;

    await Navigator.pushNamed(
      context,
      AppRoutes.accidentesEdit,
      arguments: hechoId,
    );

    if (!mounted) return;
    await _bootstrapTrackingStatusOnly();
    await _cargarHecho(hechoId);
  }

  Widget _fotosStrip(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final u = urls[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1,
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      insetPadding: const EdgeInsets.all(16),
                      child: InteractiveViewer(
                        child: Image.network(
                          u,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No se pudo cargar la imagen.'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Image.network(
                  u,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _photoCardThumbnails() {
    final lugar = _fotoLugarUrl();
    final situ = _fotoSituacionUrl();

    Widget thumb(String title, String url) {
      if (url.isEmpty) {
        return Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text('Sin $title'),
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No se pudo cargar la imagen.'),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fotos del hecho y situación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Foto del hecho',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      thumb('foto del hecho', lugar),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Foto de la situación',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      thumb('foto de la situación', situ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(
    int hechoId,
    List<String> fotosVehiculos,
    List vehiculos,
  ) {
    final h = _hecho ?? {};

    final folio = _safeText(h['folio_c5i']);
    final fecha = _safeText(h['fecha']);
    final hora = _safeText(h['hora']);

    final situacionRaw = (h['situacion'] ?? '').toString();
    final situacion = situacionRaw.trim().isEmpty
        ? '—'
        : _normalizeSituacion(situacionRaw);

    final sectorRaw = (h['sector'] ?? '').toString();
    final sector = sectorRaw.trim().isEmpty ? '—' : _normalizeSector(sectorRaw);

    final muni = _safeText(h['municipio']);
    final calle = _safeText(h['calle']);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Folio: $folio',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _goEdit(hechoId),
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Pill(icon: Icons.event, text: fecha),
                _Pill(icon: Icons.schedule, text: hora),
                _Pill(icon: Icons.flag, text: situacion),
                _Pill(icon: Icons.map, text: sector),
                _Pill(icon: Icons.location_city, text: muni),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.place, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    calle,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (fotosVehiculos.isNotEmpty) ...[
              Text(
                'Fotos (vehículos): ${fotosVehiculos.length} (vehículos: ${vehiculos.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 8),
              _fotosStrip(fotosVehiculos),
            ] else
              Text(
                'Sin fotos de vehículos registradas.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(int hechoId) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/accidentes/vehiculos',
                        arguments: {'hechoId': hechoId},
                      );
                    },
                    icon: const Icon(Icons.directions_car),
                    label: const Text('Vehículos'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.lesionados,
                        arguments: {'hechoId': hechoId},
                      );
                    },
                    icon: const Icon(Icons.personal_injury),
                    label: const Text('Lesionados'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pendiente: conectar descargo'),
                    ),
                  );
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Descargo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<_KV> items,
    bool initiallyExpanded = true,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map((e) => _KVCard(label: e.k, value: e.v, full: e.full))
                .toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hechoId = _hechoIdFromArgs(context);

    final fotosVehiculos = _fotosVehiculosDelHecho();
    final vehiculos = _vehiculosDeHecho();

    final h = _hecho ?? {};

    final identificacion = <_KV>[
      _KV('ID', _safeText(h['id'])),
      _KV('Folio C5i', _safeText(h['folio_c5i'])),
      _KV('Perito', _safeText(h['perito'])),
      _KV('Unidad', _safeText(h['unidad'])),
      _KV(
        'Situación',
        (() {
          final s = (h['situacion'] ?? '').toString().trim();
          return s.isEmpty ? '—' : _normalizeSituacion(s);
        })(),
      ),
      _KV('Tipo de hecho', _safeText(h['tipo_hecho']), full: true),
    ];

    final tiempoLugar = <_KV>[
      _KV('Fecha', _safeText(h['fecha'])),
      _KV('Hora', _safeText(h['hora'])),
      _KV(
        'Sector',
        (() {
          final s = (h['sector'] ?? '').toString().trim();
          return s.isEmpty ? '—' : _normalizeSector(s);
        })(),
      ),
      _KV('Municipio', _safeText(h['municipio'])),
      _KV('Calle', _safeText(h['calle']), full: true),
      _KV('Colonia', _safeText(h['colonia']), full: true),
      _KV('Entre calles', _safeText(h['entre_calles']), full: true),
    ];

    final clasificacion = <_KV>[
      _KV('Superficie de vía', _safeText(h['superficie_via'])),
      _KV('Tiempo', _safeText(h['tiempo'])),
      _KV('Clima', _safeText(h['clima'])),
      _KV('Condiciones', _safeText(h['condiciones'])),
      _KV('Control de tránsito', _safeText(h['control_transito']), full: true),
      _KV('Checaron antecedentes', _safeBool01(h['checaron_antecedentes'])),
      _KV('Causas', _safeText(h['causas']), full: true),
      _KV('Colisión/camino', _safeText(h['colision_camino']), full: true),
    ];

    final danos = <_KV>[
      _KV('Daños patrimoniales', _safeBool01(h['danos_patrimoniales'])),
      _KV(
        'Propiedades afectadas',
        _safeText(h['propiedades_afectadas']),
        full: true,
      ),
      _KV('Monto daños', _safeText(h['monto_danos_patrimoniales'])),
    ];

    final mp = <_KV>[
      _KV('Oficio MP', _safeText(h['oficio_mp']), full: true),
      _KV('Vehículos MP', _safeText(h['vehiculos_mp'])),
      _KV('Personas MP', _safeText(h['personas_mp'])),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: Text('Hecho #$hechoId'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit),
            onPressed: () => _goEdit(hechoId),
          ),
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.hechosBuscar),
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _bootstrapTrackingStatusOnly();
              if (hechoId > 0) await _cargarHecho(hechoId);
            },
          ),
        ],
      ),
      drawer: AppDrawer(
        trackingOn: _trackingOn,
        onLogout: () => _logout(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _bootstrapTrackingStatusOnly();
            if (hechoId > 0) await _cargarHecho(hechoId);
          },
          child: _cargando
              ? ListView(
                  children: const [
                    SizedBox(height: 140),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : (_hecho == null || _hecho!.isEmpty)
              ? const Center(child: Text('No se pudo cargar el hecho.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  children: [
                    if (_trackingOn) HeaderCard(trackingOn: _trackingOn),
                    if (_trackingOn) const SizedBox(height: 12),

                    _summaryCard(hechoId, fotosVehiculos, vehiculos),
                    const SizedBox(height: 12),

                    // ✅ ESTE ERA EL QUE FALTABA (foto_lugar / foto_situacion)
                    _photoCardThumbnails(),
                    const SizedBox(height: 12),

                    _quickActions(hechoId),
                    const SizedBox(height: 12),

                    _section(
                      title: 'Identificación',
                      icon: Icons.badge,
                      items: identificacion,
                      initiallyExpanded: true,
                    ),
                    _section(
                      title: 'Tiempo y lugar',
                      icon: Icons.place,
                      items: tiempoLugar,
                      initiallyExpanded: false,
                    ),
                    _section(
                      title: 'Clasificación',
                      icon: Icons.category,
                      items: clasificacion,
                      initiallyExpanded: false,
                    ),
                    _section(
                      title: 'Daños',
                      icon: Icons.warning_amber,
                      items: danos,
                      initiallyExpanded: false,
                    ),
                    _section(
                      title: 'Ministerio Público',
                      icon: Icons.gavel,
                      items: mp,
                      initiallyExpanded: false,
                    ),

                    const SizedBox(height: 18),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KV {
  final String k;
  final String v;
  final bool full;
  const _KV(this.k, this.v, {this.full = false});
}

class _KVCard extends StatelessWidget {
  final String label;
  final String value;
  final bool full;

  const _KVCard({required this.label, required this.value, this.full = false});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double target = full
        ? (w - 32)
        : ((w - 32 - 10) / 2); // 16+16 padding + 10 gap

    return SizedBox(
      width: target,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: value == '—' ? Colors.grey.shade700 : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

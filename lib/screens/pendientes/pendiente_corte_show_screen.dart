import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import '../../main.dart' show AppRoutes;

class PendienteCorteShowScreen extends StatefulWidget {
  const PendienteCorteShowScreen({super.key});

  @override
  State<PendienteCorteShowScreen> createState() =>
      _PendienteCorteShowScreenState();
}

class _PendienteCorteShowScreenState extends State<PendienteCorteShowScreen> {
  bool _loading = true;
  String? _error;

  int _corteId = 0;

  _CorteMeta? _meta;
  _Totales? _totales;

  List<_HechoMini> _resueltos = const [];
  List<_HechoMini> _turnados = const [];
  List<_HechoMini> _siguen = const [];
  List<_HechoMini> _otros = const [];
  List<_HechoMini> _nuevos = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    final id = _readId(args);

    if (id != 0 && id != _corteId) {
      _corteId = id;
      _fetch();
    }
  }

  int _readId(dynamic args) {
    if (args is Map) {
      final v = args['id'];
      if (v is int) return v;
      return int.tryParse('$v') ?? 0;
    }
    return 0;
  }

  Future<void> _fetch() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _PendientesService.getCorteShow(id: _corteId);

      if (!mounted) return;
      setState(() {
        _meta = data.meta;
        _totales = data.totales;
        _resueltos = data.resueltos;
        _turnados = data.turnados;
        _siguen = data.siguen;
        _otros = data.otros;
        _nuevos = data.nuevos;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _onRefresh() async => _fetch();

  void _openHecho(int id) {
    Navigator.pushNamed(
      context,
      AppRoutes.accidentesShow,
      arguments: {'id': '$id'},
    );
  }

  void _openPrev() {
    final prevId = _meta?.prevId;
    if (prevId == null || prevId == 0) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.pendientesCorteShow,
      arguments: {'id': prevId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (_meta?.corteFecha?.isNotEmpty ?? false)
        ? 'Corte ${_meta!.corteFecha}'
        : 'Detalle del corte';

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.blue,
          title: Text(title),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _fetch,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Corte anterior',
              onPressed: (_meta?.prevId ?? 0) > 0 ? _openPrev : null,
              icon: const Icon(Icons.skip_previous),
            ),
            const SizedBox(width: 6),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFFE6EEFF),
                tabs: [
                  Tab(text: 'Resueltos'),
                  Tab(text: 'Turnados'),
                  Tab(text: 'Siguen'),
                  Tab(text: 'Otros'),
                  Tab(text: 'Nuevos'),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.6))
              : (_error != null)
              ? RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [_ErrorCard(message: _error!, onRetry: _fetch)],
                  ),
                )
              : Column(
                  children: [
                    _TopSummary(meta: _meta, totales: _totales),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: TabBarView(
                          children: [
                            _HechosList(
                              items: _resueltos,
                              emptyText: 'No hay resueltos.',
                              onOpen: _openHecho,
                              accent: _Accent.success,
                            ),
                            _HechosList(
                              items: _turnados,
                              emptyText: 'No hay turnados.',
                              onOpen: _openHecho,
                              accent: _Accent.warning,
                            ),
                            _HechosList(
                              items: _siguen,
                              emptyText: 'No hay pendientes.',
                              onOpen: _openHecho,
                              accent: _Accent.danger,
                            ),
                            _HechosList(
                              items: _otros,
                              emptyText: 'No hay otros estados.',
                              onOpen: _openHecho,
                              accent: _Accent.neutral,
                            ),
                            _HechosList(
                              items: _nuevos,
                              emptyText: 'No hay nuevos pendientes.',
                              onOpen: _openHecho,
                              accent: _Accent.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PendientesService {
  static const String baseUrl = 'https://seguridadvial-mich.com/api';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<_CorteShowPayload> getCorteShow({required int id}) async {
    final uri = Uri.parse('$baseUrl/pendientes/cortes/$id');
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    if (decoded is! Map) {
      throw Exception('Respuesta inválida: se esperaba un objeto.');
    }

    final map = Map<String, dynamic>.from(decoded);

    final meta = _CorteMeta.fromJson(
      (map['corte'] is Map)
          ? Map<String, dynamic>.from(map['corte'])
          : <String, dynamic>{},
      prev: (map['prev'] is Map)
          ? Map<String, dynamic>.from(map['prev'])
          : null,
    );

    final totales = _Totales.fromJson(
      (map['totales'] is Map)
          ? Map<String, dynamic>.from(map['totales'])
          : <String, dynamic>{},
    );

    List<_HechoMini> parseList(dynamic v) {
      final out = <_HechoMini>[];
      if (v is List) {
        for (final e in v) {
          if (e is Map<String, dynamic>) out.add(_HechoMini.fromJson(e));
          if (e is Map)
            out.add(_HechoMini.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      return out;
    }

    return _CorteShowPayload(
      meta: meta,
      totales: totales,
      resueltos: parseList(map['resueltos']),
      turnados: parseList(map['turnados']),
      siguen: parseList(map['siguen']),
      otros: parseList(map['otros']),
      nuevos: parseList(map['nuevos']),
    );
  }
}

class _CorteShowPayload {
  final _CorteMeta meta;
  final _Totales totales;

  final List<_HechoMini> resueltos;
  final List<_HechoMini> turnados;
  final List<_HechoMini> siguen;
  final List<_HechoMini> otros;
  final List<_HechoMini> nuevos;

  _CorteShowPayload({
    required this.meta,
    required this.totales,
    required this.resueltos,
    required this.turnados,
    required this.siguen,
    required this.otros,
    required this.nuevos,
  });
}

class _CorteMeta {
  final int id;
  final String corteFecha;
  final String generadoAt;
  final String observaciones;
  final int prevId;
  final String prevFecha;

  _CorteMeta({
    required this.id,
    required this.corteFecha,
    required this.generadoAt,
    required this.observaciones,
    required this.prevId,
    required this.prevFecha,
  });

  factory _CorteMeta.fromJson(
    Map<String, dynamic> j, {
    Map<String, dynamic>? prev,
  }) {
    int toI(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

    final corteFecha = (j['corte_fecha'] ?? j['fecha'] ?? '')?.toString() ?? '';
    final generado = (j['created_at'] ?? '')?.toString() ?? '';
    final obs = (j['observaciones'] ?? '')?.toString() ?? '';

    final prevId = prev == null ? 0 : toI(prev['id']);
    final prevFecha = prev == null
        ? ''
        : (prev['corte_fecha'] ?? prev['fecha'] ?? '')?.toString() ?? '';

    return _CorteMeta(
      id: toI(j['id']),
      corteFecha: corteFecha,
      generadoAt: generado,
      observaciones: obs,
      prevId: prevId,
      prevFecha: prevFecha,
    );
  }
}

class _Totales {
  final int previos;
  final int resueltos;
  final int turnados;
  final int siguenPendiente;
  final int otros;
  final int nuevosPendientes;

  _Totales({
    required this.previos,
    required this.resueltos,
    required this.turnados,
    required this.siguenPendiente,
    required this.otros,
    required this.nuevosPendientes,
  });

  factory _Totales.fromJson(Map<String, dynamic> j) {
    int toI(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

    return _Totales(
      previos: toI(j['previos']),
      resueltos: toI(j['resueltos']),
      turnados: toI(j['turnados']),
      siguenPendiente: toI(j['siguen_pendiente']),
      otros: toI(j['otros']),
      nuevosPendientes: toI(j['nuevos_pendientes']),
    );
  }
}

class _HechoMini {
  final int id;
  final String fecha;
  final String unidad;
  final String situacion;

  _HechoMini({
    required this.id,
    required this.fecha,
    required this.unidad,
    required this.situacion,
  });

  factory _HechoMini.fromJson(Map<String, dynamic> j) {
    int toI(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

    String s(dynamic v) => (v == null) ? '' : v.toString();

    return _HechoMini(
      id: toI(j['id']),
      fecha: s(j['fecha']),
      unidad: s(j['unidad']),
      situacion: s(j['situacion']),
    );
  }
}

class _TopSummary extends StatelessWidget {
  final _CorteMeta? meta;
  final _Totales? totales;

  const _TopSummary({required this.meta, required this.totales});

  @override
  Widget build(BuildContext context) {
    final m = meta;
    final t = totales;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          if (t != null)
            SizedBox(
              height: 86,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children:
                    [
                          _StatChip(
                            title: 'Previos',
                            value: t.previos,
                            accent: _Accent.info,
                            icon: Icons.playlist_add_check,
                          ),
                          _StatChip(
                            title: 'Resueltos',
                            value: t.resueltos,
                            accent: _Accent.success,
                            icon: Icons.check_circle,
                          ),
                          _StatChip(
                            title: 'Turnados',
                            value: t.turnados,
                            accent: _Accent.warning,
                            icon: Icons.share,
                          ),
                          _StatChip(
                            title: 'Siguen',
                            value: t.siguenPendiente,
                            accent: _Accent.danger,
                            icon: Icons.warning_rounded,
                          ),
                          _StatChip(
                            title: 'Otros',
                            value: t.otros,
                            accent: _Accent.neutral,
                            icon: Icons.layers,
                          ),
                          _StatChip(
                            title: 'Nuevos',
                            value: t.nuevosPendientes,
                            accent: _Accent.primary,
                            icon: Icons.add_circle,
                          ),
                        ]
                        .map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: w,
                          ),
                        )
                        .toList(),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                  color: Colors.black.withOpacity(.06),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Información del corte',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Corte actual',
                  value: (m?.corteFecha ?? '').isEmpty
                      ? 'No disponible'
                      : m!.corteFecha,
                ),
                _InfoRow(
                  label: 'Corte previo',
                  value: (m?.prevFecha ?? '').isEmpty
                      ? 'No disponible'
                      : m!.prevFecha,
                ),
                _InfoRow(
                  label: 'Generado',
                  value: (m?.generadoAt ?? '').isEmpty
                      ? 'No disponible'
                      : m!.generadoAt,
                ),
                _InfoRow(
                  label: 'Obs.',
                  value: (m?.observaciones ?? '').trim().isEmpty
                      ? 'No especificado'
                      : m!.observaciones.trim(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HechosList extends StatelessWidget {
  final List<_HechoMini> items;
  final String emptyText;
  final void Function(int id) onOpen;
  final _Accent accent;

  const _HechosList({
    required this.items,
    required this.emptyText,
    required this.onOpen,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              emptyText,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final h = items[i];
        return _HechoTile(item: h, accent: accent, onOpen: () => onOpen(h.id));
      },
    );
  }
}

class _HechoTile extends StatelessWidget {
  final _HechoMini item;
  final _Accent accent;
  final VoidCallback onOpen;

  const _HechoTile({
    required this.item,
    required this.accent,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = accent.color;

    final fecha = item.fecha.trim().isEmpty ? 'Sin fecha' : item.fecha.trim();
    final unidad = item.unidad.trim().isEmpty
        ? 'Sin unidad'
        : item.unidad.trim();
    final sit = item.situacion.trim().isEmpty
        ? 'Sin situación'
        : item.situacion.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.06),
          ),
        ],
      ),
      child: ListTile(
        onTap: onOpen,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.withOpacity(.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(accent.icon, color: c),
        ),
        title: Text(
          'ID ${item.id}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniLine(icon: Icons.event, text: fecha),
              const SizedBox(height: 2),
              _MiniLine(icon: Icons.apartment, text: unidad),
              const SizedBox(height: 2),
              _MiniLine(icon: Icons.info_outline, text: sit),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: 'Ver',
          onPressed: onOpen,
          icon: const Icon(Icons.chevron_right),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade800),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String title;
  final int value;
  final _Accent accent;
  final IconData icon;

  const _StatChip({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = accent.color;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.06),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.red.withOpacity(.06),
        border: Border.all(color: Colors.red.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No se pudo cargar',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Accent { info, success, warning, danger, primary, neutral }

extension on _Accent {
  Color get color {
    switch (this) {
      case _Accent.info:
        return Colors.lightBlue;
      case _Accent.success:
        return Colors.green;
      case _Accent.warning:
        return Colors.orange;
      case _Accent.danger:
        return Colors.red;
      case _Accent.primary:
        return Colors.blue;
      case _Accent.neutral:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case _Accent.info:
        return Icons.list_alt;
      case _Accent.success:
        return Icons.check_circle;
      case _Accent.warning:
        return Icons.share;
      case _Accent.danger:
        return Icons.warning_rounded;
      case _Accent.primary:
        return Icons.add_circle;
      case _Accent.neutral:
        return Icons.layers;
    }
  }
}

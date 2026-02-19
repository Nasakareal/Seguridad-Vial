import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import '../../main.dart' show AppRoutes;

class PendientesCortesScreen extends StatefulWidget {
  const PendientesCortesScreen({super.key});

  @override
  State<PendientesCortesScreen> createState() => _PendientesCortesScreenState();
}

class _PendientesCortesScreenState extends State<PendientesCortesScreen> {
  bool _loading = true;
  String? _error;

  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  final List<_CorteItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _loadingMore = false;
        _items.clear();
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    }

    try {
      final res = await _PendientesService.getCortes(page: _page);

      if (!mounted) return;

      setState(() {
        _items.addAll(res.items);
        _hasMore = res.hasMore;
        _page = res.nextPage;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _onRefresh() async => _fetch(reset: true);

  void _openCorte(_CorteItem c) {
    Navigator.pushNamed(
      context,
      AppRoutes.pendientesCorteShow,
      arguments: {'id': c.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Cortes pendientes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => _fetch(reset: true),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _onRefresh, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.6));
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _ErrorCard(message: _error!, onRetry: () => _fetch(reset: true)),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.date_range, color: Colors.blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cortes: ${_items.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ..._items.map((c) => _CorteTile(item: c, onTap: () => _openCorte(c))),
        const SizedBox(height: 10),
        if (_error != null && _items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ErrorCard(
              message: _error!,
              onRetry: () => _fetch(reset: false),
            ),
          ),
        if (_hasMore)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loadingMore ? null : () => _fetch(reset: false),
              icon: _loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(_loadingMore ? 'Cargando...' : 'Cargar más'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No hay más cortes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
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

  static Future<_CortesPage> getCortes({required int page}) async {
    final uri = Uri.parse(
      '$baseUrl/pendientes/cortes',
    ).replace(queryParameters: {'page': '$page'});

    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    List list;
    int? currentPage;
    int? lastPage;

    if (decoded is Map && decoded['data'] is List) {
      list = decoded['data'] as List;
      currentPage = _toInt(decoded['current_page']);
      lastPage = _toInt(decoded['last_page']);
    } else if (decoded is List) {
      list = decoded;
    } else {
      list = const [];
    }

    final items = <_CorteItem>[];
    for (final e in list) {
      if (e is Map<String, dynamic>) {
        items.add(_CorteItem.fromJson(e));
      } else if (e is Map) {
        items.add(_CorteItem.fromJson(Map<String, dynamic>.from(e)));
      }
    }

    if (currentPage != null && lastPage != null) {
      final hasMore = currentPage < lastPage;
      return _CortesPage(
        items: items,
        hasMore: hasMore,
        nextPage: hasMore ? (currentPage + 1) : currentPage,
      );
    }

    final hasMore = items.length >= 30;
    return _CortesPage(items: items, hasMore: hasMore, nextPage: page + 1);
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }
}

class _CortesPage {
  final List<_CorteItem> items;
  final bool hasMore;
  final int nextPage;

  _CortesPage({
    required this.items,
    required this.hasMore,
    required this.nextPage,
  });
}

class _CorteItem {
  final int id;
  final String corteFecha;

  _CorteItem({required this.id, required this.corteFecha});

  factory _CorteItem.fromJson(Map<String, dynamic> j) {
    int toI(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

    return _CorteItem(
      id: toI(j['id']),
      corteFecha: (j['corte_fecha'] ?? j['fecha'] ?? '')?.toString() ?? '',
    );
  }
}

class _CorteTile extends StatelessWidget {
  final _CorteItem item;
  final VoidCallback onTap;

  const _CorteTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = item.corteFecha.isEmpty
        ? 'Corte #${item.id}'
        : 'Corte: ${item.corteFecha}';

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
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.event_note, color: Colors.blue),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          'Abrir detalle',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        trailing: const Icon(Icons.chevron_right),
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

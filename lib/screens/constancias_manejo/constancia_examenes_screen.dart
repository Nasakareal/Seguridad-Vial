import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/constancia_manejo.dart';
import '../../services/constancias_manejo_service.dart';
import 'constancia_manejo_scan_screen.dart';

class ConstanciaExamenesScreen extends StatefulWidget {
  const ConstanciaExamenesScreen({super.key});

  @override
  State<ConstanciaExamenesScreen> createState() =>
      _ConstanciaExamenesScreenState();
}

class _ConstanciaExamenesScreenState extends State<ConstanciaExamenesScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ConstanciaExamenSolicitud> _items = [];

  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  int? _openingId;
  String? _estatus;
  String? _modalidad;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_maybeLoadMore);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
        _lastPage = 1;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final result = await ConstanciasManejoService.examenes(
        estatus: _estatus,
        modalidad: _modalidad,
        buscar: _searchCtrl.text,
        page: reset ? 1 : _page + 1,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(result.items);
        } else {
          _items.addAll(result.items);
        }
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _total = result.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = ConstanciasManejoService.cleanExceptionMessage(error);
      });
    }
  }

  void _maybeLoadMore() {
    if (_loading || _loadingMore || _page >= _lastPage) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 320) {
      unawaited(_load(reset: false));
    }
  }

  Future<void> _open(ConstanciaExamenSolicitud examen) async {
    if (_openingId != null) return;
    setState(() => _openingId = examen.id);
    try {
      final updated = await ConstanciasManejoService.fetchExamen(examen.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ConstanciaExamenSolicitudDetailScreen(initialExamen: updated),
        ),
      );
      if (mounted) unawaited(_load(reset: true));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ConstanciasManejoService.cleanExceptionMessage(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Exámenes registrados'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => unawaited(_load(reset: true)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ExamFilters(
              searchCtrl: _searchCtrl,
              estatus: _estatus,
              modalidad: _modalidad,
              total: _total,
              onSearch: () => unawaited(_load(reset: true)),
              onStatusChanged: (value) {
                setState(() => _estatus = value);
                unawaited(_load(reset: true));
              },
              onModalityChanged: (value) {
                setState(() => _modalidad = value);
                unawaited(_load(reset: true));
              },
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => unawaited(_load(reset: true)),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Icon(Icons.assignment_outlined, size: 52, color: Colors.grey),
                SizedBox(height: 12),
                Center(child: Text('No hay exámenes para mostrar.')),
              ],
            )
          : ListView.separated(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final examen = _items[index];
                return _ExamTile(
                  examen: examen,
                  loading: _openingId == examen.id,
                  onOpen: () => _open(examen),
                );
              },
            ),
    );
  }
}

class _ExamFilters extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String? estatus;
  final String? modalidad;
  final int total;
  final VoidCallback onSearch;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onModalityChanged;

  const _ExamFilters({
    required this.searchCtrl,
    required this.estatus,
    required this.modalidad,
    required this.total,
    required this.onSearch,
    required this.onStatusChanged,
    required this.onModalityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          children: [
            TextField(
              controller: searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: InputDecoration(
                hintText: 'Buscar por folio, nombre, CURP o teléfono',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  onPressed: onSearch,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: estatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'PENDIENTE',
                        child: Text('Pendientes'),
                      ),
                      DropdownMenuItem(
                        value: 'APROBADO',
                        child: Text('Aprobados'),
                      ),
                      DropdownMenuItem(
                        value: 'REPROBADO',
                        child: Text('Reprobados'),
                      ),
                    ],
                    onChanged: onStatusChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: modalidad,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Modalidad',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todas')),
                      DropdownMenuItem(value: 'LINEA', child: Text('En línea')),
                      DropdownMenuItem(
                        value: 'IMPRESO',
                        child: Text('Impreso'),
                      ),
                    ],
                    onChanged: onModalityChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$total examen${total == 1 ? '' : 'es'}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  final ConstanciaExamenSolicitud examen;
  final bool loading;
  final VoidCallback onOpen;

  const _ExamTile({
    required this.examen,
    required this.loading,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final constancia = examen.constanciaFolio?.trim() ?? '';
    final date = _formatDate(examen.fechaExamen ?? examen.createdAt);
    final action = examen.puedeActivarConstancia
        ? 'Listo para activar constancia'
        : constancia.isNotEmpty
        ? 'Constancia $constancia'
        : examen.estatus.toUpperCase() == 'PENDIENTE'
        ? 'Examen pendiente de resultado'
        : 'Consulta el detalle del examen';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: loading ? null : onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      examen.folioExamen,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _ExamStatusPill(
                    label: constancia.isNotEmpty ? 'ASIGNADO' : examen.estatus,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                examen.nombreSolicitante,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                [
                  examen.tipoLicencia.replaceAll('_', ' '),
                  examen.modalidad == 'LINEA' ? 'EN LÍNEA' : examen.modalidad,
                  if (date.isNotEmpty) date,
                ].where((item) => item.trim().isNotEmpty).join(' · '),
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    examen.puedeActivarConstancia
                        ? Icons.verified_outlined
                        : Icons.info_outline,
                    size: 18,
                    color: examen.puedeActivarConstancia
                        ? const Color(0xFF15803D)
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      action,
                      style: TextStyle(
                        color: examen.puedeActivarConstancia
                            ? const Color(0xFF15803D)
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return '';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _ExamStatusPill extends StatelessWidget {
  final String label;

  const _ExamStatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = switch (label.trim().toUpperCase()) {
      'APROBADO' => const Color(0xFF15803D),
      'ASIGNADO' => const Color(0xFF1D4ED8),
      'REPROBADO' => const Color(0xFFB91C1C),
      'PENDIENTE' => const Color(0xFFB45309),
      _ => const Color(0xFF475569),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

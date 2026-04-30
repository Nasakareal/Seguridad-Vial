import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../models/constancia_manejo.dart';
import '../../services/constancias_manejo_service.dart';

class ConstanciasManejoScreen extends StatefulWidget {
  const ConstanciasManejoScreen({super.key});

  @override
  State<ConstanciasManejoScreen> createState() =>
      _ConstanciasManejoScreenState();
}

class _ConstanciasManejoScreenState extends State<ConstanciasManejoScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<ConstanciaManejo> _items = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _estatus;
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
      final result = await ConstanciasManejoService.index(
        estatus: _estatus,
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = ConstanciasManejoService.cleanExceptionMessage(e);
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

  Future<void> _openUrl(String? rawUrl) async {
    final value = rawUrl?.trim() ?? '';
    if (value.isEmpty) {
      _showSnack('No hay liga de impresion disponible.');
      return;
    }

    final uri = Uri.tryParse(value);
    if (uri == null) {
      _showSnack('La liga de impresion no es valida.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _showSnack('No se pudo abrir la liga de impresion.');
  }

  Future<void> _createBatch() async {
    final result = await showDialog<ConstanciasManejoCreateResult>(
      context: context,
      builder: (context) => const _CreateBatchDialog(),
    );
    if (result == null || !mounted) return;

    await _load(reset: true);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        action: (result.urlImprimirLote ?? '').trim().isEmpty
            ? null
            : SnackBarAction(
                label: 'Imprimir',
                onPressed: () => unawaited(_openUrl(result.urlImprimirLote)),
              ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Constancias de manejo'),
        actions: [
          IconButton(
            tooltip: 'Escanear QR',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.constanciasManejoScanner,
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_load(reset: true)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBatch,
        icon: const Icon(Icons.add),
        label: const Text('Generar lote'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Filters(
              searchCtrl: _searchCtrl,
              selectedStatus: _estatus,
              total: _total,
              onStatusChanged: (value) {
                setState(() => _estatus = value);
                unawaited(_load(reset: true));
              },
              onSearch: () => unawaited(_load(reset: true)),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _ErrorState(
                      message: _error!,
                      onRetry: () => _load(reset: true),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: _items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    'No hay constancias para mostrar.',
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              controller: _scrollCtrl,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
                              itemCount: _items.length + (_loadingMore ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                if (index >= _items.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final item = _items[index];
                                return _ConstanciaTile(
                                  constancia: item,
                                  onOpen: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.constanciasManejoDetalle,
                                    arguments: item,
                                  ),
                                  onPrint: () =>
                                      unawaited(_openUrl(item.urlImprimir)),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String? selectedStatus;
  final int total;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onSearch;

  const _Filters({
    required this.searchCtrl,
    required this.selectedStatus,
    required this.total,
    required this.onStatusChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    const options = <String?, String>{
      null: 'Todas',
      'IMPRESA_INACTIVA': 'Inactivas',
      'ACTIVA': 'Activas',
      'CANCELADA': 'Canceladas',
      'EXPIRADA': 'Expiradas',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar folio, nombre o CURP',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Buscar',
                onPressed: onSearch,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selectedStatus == entry.key,
                    label: Text(entry.value),
                    onSelected: (_) => onStatusChanged(entry.key),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$total constancias',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateBatchDialog extends StatefulWidget {
  const _CreateBatchDialog();

  @override
  State<_CreateBatchDialog> createState() => _CreateBatchDialogState();
}

class _CreateBatchDialogState extends State<_CreateBatchDialog> {
  final _cantidadCtrl = TextEditingController(text: '1');
  List<ConstanciaModulo> _modulos = const [];
  int? _moduloId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadModules());
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModules() async {
    try {
      final modulos = await ConstanciasManejoService.modulos();
      if (!mounted) return;
      setState(() {
        _modulos = modulos;
        _moduloId = modulos.isNotEmpty ? modulos.first.id : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ConstanciasManejoService.cleanExceptionMessage(e);
      });
    }
  }

  Future<void> _save() async {
    final moduloId = _moduloId;
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;
    if (moduloId == null) {
      setState(() => _error = 'Selecciona un modulo.');
      return;
    }
    if (cantidad < 1 || cantidad > 100) {
      setState(() => _error = 'La cantidad debe ser de 1 a 100.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await ConstanciasManejoService.crearLote(
        moduloId: moduloId,
        cantidad: cantidad,
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = ConstanciasManejoService.cleanExceptionMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generar constancias'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: _moduloId,
                    decoration: const InputDecoration(
                      labelText: 'Modulo',
                      border: OutlineInputBorder(),
                    ),
                    items: _modulos
                        .map(
                          (modulo) => DropdownMenuItem<int>(
                            value: modulo.id,
                            child: Text(
                              modulo.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _moduloId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cantidadCtrl,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      helperText: 'Maximo 100 por lote',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if ((_error ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.print),
          label: Text(_saving ? 'Generando...' : 'Generar'),
        ),
      ],
    );
  }
}

class _ConstanciaTile extends StatelessWidget {
  final ConstanciaManejo constancia;
  final VoidCallback onOpen;
  final VoidCallback onPrint;

  const _ConstanciaTile({
    required this.constancia,
    required this.onOpen,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
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
                      constancia.folio,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusPill(label: constancia.estatus),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                constancia.nombreSolicitante ?? 'Sin solicitante',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  constancia.modulo,
                  constancia.tipoLicencia?.replaceAll('_', ' '),
                  constancia.resultado,
                ].where((item) => (item ?? '').trim().isNotEmpty).join(' | '),
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPrint,
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimir'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Abrir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = switch (label.trim().toUpperCase()) {
      'ACTIVA' => const Color(0xFF15803D),
      'IMPRESA_INACTIVA' => const Color(0xFFB45309),
      'CANCELADA' => const Color(0xFFB91C1C),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/vialidades_urbanas_dispositivo.dart';
import '../../services/app_version_service.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/vialidades_urbanas_service.dart';
import '../../services/vialidades_urbanas_share_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/header_card.dart';
import '../login_screen.dart';

class VialidadesUrbanasScreen extends StatefulWidget {
  const VialidadesUrbanasScreen({super.key});

  @override
  State<VialidadesUrbanasScreen> createState() =>
      _VialidadesUrbanasScreenState();
}

class _VialidadesUrbanasScreenState extends State<VialidadesUrbanasScreen>
    with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _bootstrapped = false;
  bool _busy = false;
  bool _loading = true;
  bool _hasAccess = false;
  bool _canCreate = false;

  String? _error;

  DateTime _selectedDate = DateTime.now();
  List<VialidadesUrbanasCatalogo> _catalogos =
      const <VialidadesUrbanasCatalogo>[];
  List<VialidadesUrbanasDispositivo> _items =
      const <VialidadesUrbanasDispositivo>[];
  VialidadesUrbanasTotales _totales = const VialidadesUrbanasTotales();
  int? _catalogoFiltroId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
      } catch (_) {}

      if (!mounted) return;
      await _bootstrapTrackingStatusOnly();
      if (!mounted) return;
      await _resolveAccess();
      if (!mounted || !_hasAccess) return;
      await _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final running = await TrackingService.isRunning();
      if (!mounted) return;
      setState(() => _trackingOn = running);
    }
  }

  Future<void> _bootstrapTrackingStatusOnly() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final running = await TrackingService.isRunning();
    if (!mounted) return;
    setState(() => _trackingOn = running);
  }

  Future<void> _resolveAccess() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final canSee = await AuthService.isVialidadesUrbanasUser(refresh: true);
      final hasFullOperationalAccess =
          await AuthService.hasFullOperationalAccess();
      final canCreate =
          hasFullOperationalAccess ||
          await AuthService.can('crear operativos vialidades');

      if (!canSee) {
        throw Exception(
          'Este menu es exclusivo para usuarios de la Unidad de Proteccion en Vialidades Urbanas.',
        );
      }

      if (!mounted) return;
      setState(() {
        _hasAccess = true;
        _canCreate = canCreate;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasAccess = false;
        _canCreate = false;
        _loading = false;
        _error = '$e';
      });
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

  String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _fmtDmY(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });

    await _load();
  }

  Future<void> _load() async {
    if (!mounted || !_hasAccess) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        VialidadesUrbanasService.fetchIndex(fecha: _selectedDate),
        VialidadesUrbanasService.fetchResumen(fecha: _selectedDate),
      ]);

      final index = results[0] as VialidadesUrbanasIndexResult;
      final resumen = results[1] as VialidadesUrbanasTotales;

      if (!mounted) return;
      setState(() {
        _catalogos = index.catalogos;
        _items = index.items;
        _totales = resumen;
        if (_catalogoFiltroId != null &&
            !_catalogos.any((catalogo) => catalogo.id == _catalogoFiltroId)) {
          _catalogoFiltroId = null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const <VialidadesUrbanasDispositivo>[];
        _totales = const VialidadesUrbanasTotales();
        _loading = false;
        _error = 'No se pudieron cargar los dispositivos.\n$e';
      });
    }
  }

  Future<void> _shareResumen() async {
    try {
      final texto = await VialidadesUrbanasService.fetchWhatsappText(
        fecha: _selectedDate,
      );
      await VialidadesUrbanasShareService.compartirTextoEnWhatsapp(
        texto: texto,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir el resumen.\n$e')),
      );
    }
  }

  Future<void> _goCreate() async {
    final created = await Navigator.pushNamed(
      context,
      AppRoutes.vialidadesUrbanasCreate,
    );

    if (created == true && mounted) {
      await _load();
    }
  }

  Future<void> _goChildShow(int dispositivoId) async {
    final refreshed = await Navigator.pushNamed(
      context,
      AppRoutes.vialidadesUrbanasDispositivoShow,
      arguments: <String, dynamic>{'dispositivoId': dispositivoId},
    );

    if (refreshed == true && mounted) {
      await _load();
    }
  }

  void _showResumen(VialidadesUrbanasDispositivo item) {
    final coverUrl = VialidadesUrbanasService.toPublicUrl(item.portadaRuta);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            shrinkWrap: true,
            children: [
              if (coverUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    coverUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: const Color(0xFFE2E8F0),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported, size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                item.asunto.isEmpty ? item.catalogoNombre : item.asunto,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniTag(text: item.catalogoNombre),
                  if (item.fecha.isNotEmpty) _MiniTag(text: item.fecha),
                  if (item.hora.isNotEmpty)
                    _MiniTag(text: _shortHour(item.hora)),
                  _MiniTag(text: '${item.fotosCount} fotos'),
                ],
              ),
              const SizedBox(height: 14),
              _InfoRow(label: 'Lugar', value: item.ubicacionResumen),
              if (item.evento.isNotEmpty)
                _InfoRow(label: 'Evento', value: item.evento),
              if (item.supervision.isNotEmpty)
                _InfoRow(label: 'Supervision', value: item.supervision),
              if (item.creadorNombre.isNotEmpty)
                _InfoRow(label: 'Creado por', value: item.creadorNombre),
              const SizedBox(height: 10),
              const Text(
                'Resumen',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(item.resumen),
              if (item.objetivo.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Objetivo',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(item.objetivo),
              ],
              if (item.narrativa.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Narrativa',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(item.narrativa),
              ],
              if (item.accionesRealizadas.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Acciones realizadas',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(item.accionesRealizadas),
              ],
              if (item.observaciones.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Observaciones',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(item.observaciones),
              ],
              const SizedBox(height: 12),
              const Text(
                'Estado de fuerza',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: item.estadoFuerzaEtiquetas.isEmpty
                    ? const <Widget>[Text('Sin datos capturados.')]
                    : item.estadoFuerzaEtiquetas
                          .map((value) => _MiniTag(text: value))
                          .toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _shareResumen,
                icon: const Icon(Icons.share),
                label: const Text('Compartir resumen'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _shortHour(String raw) {
    final value = raw.trim();
    if (value.length >= 5) {
      return value.substring(0, 5);
    }
    return value;
  }

  Widget _filtersBar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mostrando: ${_fmtYmd(_selectedDate)}',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _fmtDmY(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int?>(
          value: _catalogoFiltroId,
          items: <DropdownMenuItem<int?>>[
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Todos los catalogos'),
            ),
            ..._catalogos.map(
              (catalogo) => DropdownMenuItem<int?>(
                value: catalogo.id,
                child: Text(catalogo.nombre),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => _catalogoFiltroId = value);
          },
          decoration: InputDecoration(
            labelText: 'Catalogo',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _shareResumen,
            icon: const Icon(Icons.share),
            label: const Text('Compartir resumen'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _catalogoFiltroId == null
        ? _items
        : _items.where((item) => item.catalogoId == _catalogoFiltroId).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Vialidades Urbanas'),
        actions: const [AccountMenuAction()],
      ),
      drawer: AppDrawer(trackingOn: _trackingOn),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _bootstrapTrackingStatusOnly();
            await _resolveAccess();
            if (_hasAccess) {
              await _load();
            }
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_trackingOn) HeaderCard(trackingOn: _trackingOn),
              if (_trackingOn) const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.blue.withValues(alpha: .06),
                  border: Border.all(color: Colors.blue.withValues(alpha: .18)),
                ),
                child: _filtersBar(),
              ),
              const SizedBox(height: 12),
              _SummaryGrid(
                totales: _totales,
                selectedDate: _fmtDmY(_selectedDate),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Center(
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              else if (filteredItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('No hay dispositivos para este filtro.'),
                  ),
                )
              else
                ...filteredItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DispositivoCard(
                      item: item,
                      onSummary: () => _showResumen(item),
                      onOpen: () => _goChildShow(item.id),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: _goCreate,
              tooltip: 'Agregar dispositivo',
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            )
          : null,
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final VialidadesUrbanasTotales totales;
  final String selectedDate;

  const _SummaryGrid({required this.totales, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryItem(
                label: 'Dispositivos',
                value: '${totales.dispositivos}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryItem(
                label: 'Elementos',
                value: '${totales.elementos}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryItem(
                label: 'Unidades',
                value: '${totales.totalUnidades}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryItem(label: 'Fenix', value: '${totales.fenix}'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SummaryItem(label: 'Fecha', value: selectedDate, fullWidth: true),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final bool fullWidth;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DispositivoCard extends StatelessWidget {
  final VialidadesUrbanasDispositivo item;
  final VoidCallback onSummary;
  final VoidCallback onOpen;

  const _DispositivoCard({
    required this.item,
    required this.onSummary,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = VialidadesUrbanasService.toPublicUrl(item.portadaRuta);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coverUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                coverUrl,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: const Color(0xFFE2E8F0),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported, size: 36),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.asunto.isEmpty ? item.catalogoNombre : item.asunto,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      '#${item.id}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.ubicacionResumen,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.resumen,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniTag(text: item.catalogoNombre),
                    if (item.fecha.isNotEmpty) _MiniTag(text: item.fecha),
                    if (item.hora.isNotEmpty)
                      _MiniTag(text: _shortHour(item.hora)),
                    if (item.creadorNombre.isNotEmpty)
                      _MiniTag(text: item.creadorNombre),
                    _MiniTag(text: '${item.fotosCount} fotos'),
                    _MiniTag(text: '${item.detallesCount} detalles'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSummary,
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Resumen'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Detalles'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortHour(String raw) {
    final value = raw.trim();
    if (value.length >= 5) {
      return value.substring(0, 5);
    }
    return value;
  }
}

class _MiniTag extends StatelessWidget {
  final String text;

  const _MiniTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
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
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
